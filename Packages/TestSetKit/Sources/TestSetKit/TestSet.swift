import Foundation

/// The only way brain tests reach the labeled frames (FR-004). Tests filter by labels, never by path.
public struct TestSet: Sendable {
    public static let environmentKey = "PHOTOSHAPE_TESTSET"
    public static let directoryName = "TestSet"
    public static let imageExtensions: Set<String> = ["heic", "heif", "jpg", "jpeg", "png"]

    public let root: URL
    /// Valid, labeled frames sorted by `id` (SC-003).
    public let frames: [TestFrame]
    public let report: ValidationReport

    public func frames(where predicate: (TestFrame) -> Bool) -> [TestFrame] { frames.filter(predicate) }

    /// Finds the set via `PHOTOSHAPE_TESTSET`, else the nearest `TestSet/` directory above `startingAt`.
    /// Brain tests call `TestSet.locate()`; the default start is the calling test file.
    public static func locate(environment: [String: String] = ProcessInfo.processInfo.environment,
                              startingAt start: String = #filePath) throws -> TestSet {
        if let path = environment[environmentKey], !path.isEmpty {
            return try load(at: URL(fileURLWithPath: path, isDirectory: true))
        }
        var dir = URL(fileURLWithPath: start).deletingLastPathComponent()
        while true {
            let candidate = dir.appendingPathComponent(directoryName, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                return try load(at: candidate)
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        throw TestSetError.notFound("set \(environmentKey) or create a \(directoryName)/ directory at the repo root")
    }

    public static func load(at root: URL) throws -> TestSet {
        let root = root.standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            throw TestSetError.notFound(root.path)
        }

        var images: [String: [URL]] = [:]   // label path (relative, no extension) → images
        var labelFiles: [String: URL] = [:]
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                        options: [.skipsHiddenFiles])
        while let url = enumerator?.nextObject() as? URL {
            guard (try? url.resourceValues(forKeys: Set(keys)).isRegularFile) == true else { continue }
            let ext = url.pathExtension.lowercased()
            let stemPath = relativePath(of: url.deletingPathExtension(), in: root)
            if imageExtensions.contains(ext) {
                images[stemPath, default: []].append(url)
            } else if ext == "json" {
                labelFiles[stemPath] = url
            }
        }

        var issues: [LabelIssue] = []
        var unlabeled: [String] = []
        var candidates: [TestFrame] = []

        for stemPath in images.keys.sorted() {
            let urls = images[stemPath]!.sorted { $0.path < $1.path }
            guard let labelURL = labelFiles[stemPath] else {
                unlabeled += urls.map { relativePath(of: $0, in: root) }
                continue
            }
            let labelName = relativePath(of: labelURL, in: root)
            guard urls.count == 1 else {
                let names = urls.map(\.lastPathComponent).joined(separator: ", ")
                issues.append(LabelIssue(file: labelName, field: nil, message: "ambiguous: several images (\(names)) share this label file"))
                continue
            }
            let imageURL = urls[0]
            let stem = imageURL.deletingPathExtension().lastPathComponent

            let dict: [String: Any]
            do {
                guard let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: labelURL)) as? [String: Any] else {
                    issues.append(LabelIssue(file: labelName, field: nil, message: "top level must be a JSON object"))
                    continue
                }
                dict = obj
            } catch {
                issues.append(LabelIssue(file: labelName, field: nil, message: "invalid JSON: \(error.localizedDescription)"))
                continue
            }

            switch LabelSchema.parse(dict, expectedID: stem) {
            case .failure(let errors):
                issues += errors.issues.map { LabelIssue(file: labelName, field: $0.field, message: $0.message) }
            case .success(let labels):
                do {
                    let metadata = try FileMetadata.read(from: imageURL)
                    candidates.append(TestFrame(id: labels.id, imageURL: imageURL, labelURL: labelURL,
                                                labels: labels, metadata: metadata))
                } catch {
                    issues.append(LabelIssue(file: relativePath(of: imageURL, in: root), field: nil, message: "\(error)"))
                }
            }
        }

        let orphans = labelFiles.keys.filter { images[$0] == nil }.map { relativePath(of: labelFiles[$0]!, in: root) }.sorted()

        // ids must be unique across sub-directories.
        let byID = Dictionary(grouping: candidates, by: \.id)
        var frames: [TestFrame] = []
        for id in byID.keys.sorted() {
            let group = byID[id]!
            if group.count == 1 { frames.append(group[0]); continue }
            let paths = group.map { relativePath(of: $0.imageURL, in: root) }.sorted()
            for path in paths {
                issues.append(LabelIssue(file: path, field: "id", message: "duplicate id \"\(id)\" (also: \(paths.filter { $0 != path }.joined(separator: ", ")))"))
            }
        }

        issues.sort { ($0.file, $0.field ?? "") < ($1.file, $1.field ?? "") }
        let gaps = frames.flatMap { frame in
            LabelSchema.gaps(for: frame.labels).map {
                LabelIssue(file: relativePath(of: frame.labelURL, in: root), field: $0.field, message: $0.message)
            }
        }
        let report = ValidationReport(issues: issues, gaps: gaps, unlabeled: unlabeled.sorted(), orphanLabels: orphans)
        return TestSet(root: root, frames: frames, report: report)
    }

    public static func relativePath(of url: URL, in root: URL) -> String {
        let full = url.standardizedFileURL.path
        let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return full.hasPrefix(base) ? String(full.dropFirst(base.count)) : full
    }
}

public struct LabelIssue: Sendable, Hashable {
    /// Path relative to the set root.
    public let file: String
    public let field: String?
    public let message: String
}

public struct ValidationReport: Sendable {
    public let issues: [LabelIssue]
    /// Expected but missing fields on otherwise valid frames (e.g. regions). Frames stay usable;
    /// criteria that need the field skip them. `testset validate --strict` fails on gaps.
    public let gaps: [LabelIssue]
    /// Images without a label file. Listed but not errors; such frames are not used in tests.
    public let unlabeled: [String]
    /// Label files without an image.
    public let orphanLabels: [String]

    public var isValid: Bool { issues.isEmpty && orphanLabels.isEmpty }
}
