import CompositionKit
import CoreImage
import Foundation
import LookKit
import UIKit

/// Example photos the user picked ("Örneklerim", spec 05 FR-007). Only a small icon and the statistics are
/// kept, never the full image (Hikâye 6.2); nothing leaves the device (Constitution I).
@MainActor @Observable
final class ReferenceStore {
    struct Reference: Codable, Identifiable, Hashable {
        let id: UUID
        let created: Date
        let profile: ReferenceProfile
        /// Main subject of the example (person with pose, or object), in the example's own coordinates (spec 04).
        var subject: Subject?
        /// Width / height of the example, to fit it into the 4:5 frame.
        var aspect: Double?
    }

    private(set) var references: [Reference] = []
    private(set) var currentID: UUID?
    private(set) var isAnalyzing = false
    /// Set when the last picked image could not be used.
    private(set) var failedToRead = false
    /// "Örneksiz çek" for this session: the prompt is not shown again until the next launch.
    var skippedPrompt = false

    private let directory: URL
    private let defaults: UserDefaults
    private var thumbnails: [UUID: UIImage] = [:]
    private var ghosts: [UUID: UIImage] = [:]
    private enum Keys { static let current = "reference.current" }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("References", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if DEBUG
        if defaults.bool(forKey: "ResetReferences") { try? FileManager.default.removeItem(at: indexURL); defaults.removeObject(forKey: Keys.current) }
        #endif
        if let data = try? Data(contentsOf: indexURL), let list = try? JSONDecoder().decode([Reference].self, from: data) {
            references = list
        }
        let saved = defaults.string(forKey: Keys.current).flatMap(UUID.init)
        currentID = references.contains { $0.id == saved } ? saved : nil
    }

    var current: Reference? { references.first { $0.id == currentID } }

    func select(_ id: UUID?) {
        currentID = id
        defaults.set(id?.uuidString, forKey: Keys.current)
    }

    /// "Örneksiz çek" from the examples list: back to the plain camera, not to the first-launch prompt.
    func shootWithoutExample() {
        select(nil)
        skippedPrompt = true
    }

    func delete(_ id: UUID) {
        references.removeAll { $0.id == id }
        thumbnails[id] = nil
        try? FileManager.default.removeItem(at: thumbnailURL(id))
        try? FileManager.default.removeItem(at: ghostURL(id))
        ghosts[id] = nil
        if currentID == id { shootWithoutExample() }
        saveIndex()
    }

    func thumbnail(_ id: UUID) -> UIImage? {
        if let cached = thumbnails[id] { return cached }
        let image = UIImage(contentsOfFile: thumbnailURL(id).path)
        thumbnails[id] = image
        return image
    }

    /// Outline of the example drawn over the live view (spec 04 "Taslak", Constitution 1.2.0).
    func ghost(_ id: UUID) -> UIImage? {
        if let cached = ghosts[id] { return cached }
        let image = UIImage(contentsOfFile: ghostURL(id).path)
        ghosts[id] = image
        return image
    }

    /// Analyzes a picked image off the main thread, stores it and makes it current.
    func add(imageData: Data) async {
        isAnalyzing = true
        failedToRead = false
        defer { isAnalyzing = false }
        let result = await Task.detached(priority: .userInitiated) { () -> Analysis? in
            guard let upright = Self.upright(imageData, maxSide: 1024), let sample = SceneSample(image: upright),
                  let thumb = Self.upright(imageData, maxSide: 300).flatMap({ UIImage(cgImage: $0).jpegData(compressionQuality: 0.85) })
            else { return nil }
            return Analysis(profile: ReferenceProfile(sample: sample), subject: SubjectDetector.detect(in: upright),
                            aspect: Double(upright.width) / Double(max(upright.height, 1)),
                            thumbnail: thumb, ghost: Self.outline(of: upright))
        }.value
        guard let result else { failedToRead = true; return }
        let reference = Reference(id: UUID(), created: Date(), profile: result.profile, subject: result.subject, aspect: result.aspect)
        try? result.thumbnail.write(to: thumbnailURL(reference.id))
        try? result.ghost?.write(to: ghostURL(reference.id))
        let profile = result.profile
        references.insert(reference, at: 0)
        saveIndex()
        select(reference.id)
        Diagnostics.log("reference added: meanL \(profile.stats.meanL), chroma \(profile.stats.meanChroma), subject \(result.subject?.kind.rawValue ?? "none")")
    }

    // MARK: - Files

    private var indexURL: URL { directory.appendingPathComponent("references.json") }
    private func thumbnailURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).jpg") }
    private func ghostURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString)-ghost.png") }

    private struct Analysis: Sendable {
        let profile: ReferenceProfile
        let subject: Subject?
        let aspect: Double
        let thumbnail: Data
        let ghost: Data?
    }

    /// White edge lines on transparent, ≤ 720 px: enough to line up with, not a copy of the photo.
    nonisolated static func outline(of image: CGImage) -> Data? {
        let input = CIImage(cgImage: image)
        let scale = min(1, 720 / max(input.extent.width, input.extent.height))
        let edges = input
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .applyingGaussianBlur(sigma: 1.2)
            .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 4])
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.6])
            .applyingFilter("CIMaskToAlpha")
        let extent = CGRect(x: 0, y: 0, width: (input.extent.width * scale).rounded(), height: (input.extent.height * scale).rounded())
        let context = CIContext()
        guard let cg = context.createCGImage(edges.cropped(to: extent), from: extent) else { return nil }
        return UIImage(cgImage: cg).pngData()
    }

    private func saveIndex() {
        if let data = try? JSONEncoder().encode(references) { try? data.write(to: indexURL, options: .atomic) }
    }

    /// Decodes with EXIF orientation applied and the long side limited.
    nonisolated static func upright(_ data: Data, maxSide: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
