import Foundation

/// Reads and rewrites label files without touching fields the caller did not change.
/// Output keeps schema field order (unknown keys last, sorted) so diffs stay readable.
public enum LabelFile {
    public static func readDictionary(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard let dict = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw LabelFileError.notAnObject(url.lastPathComponent)
        }
        return dict
    }

    /// Sets `subject_region` / `neutral_region`; `nil` or `[]` removes the key. Creates the file
    /// (with only `id`) when it does not exist yet.
    public static func setRegions(subject: Region?, neutral: [Region], at url: URL) throws {
        var dict = try readDictionary(at: url)
        if dict["id"] == nil { dict["id"] = url.deletingPathExtension().lastPathComponent }
        dict["subject_region"] = subject?.jsonObject
        dict["neutral_region"] = neutral.isEmpty ? nil : neutral.map(\.jsonObject)
        try Data(serialize(dict).utf8).write(to: url, options: .atomic)
    }

    public static func regions(in dict: [String: Any]) -> (subject: Region?, neutral: [Region]) {
        let subject = dict["subject_region"].flatMap(LabelSchema.region(from:))
        let neutral = (dict["neutral_region"] as? [Any])?.compactMap(LabelSchema.region(from:)) ?? []
        return (subject, neutral)
    }

    static func serialize(_ dict: [String: Any]) throws -> String {
        let order = LabelSchema.fields.map(\.key)
        let keys = order.filter { dict[$0] != nil } + dict.keys.filter { !order.contains($0) }.sorted()
        var lines: [String] = []
        for key in keys {
            lines.append("  \(try fragment(key)): \(try value(dict[key]!))")
        }
        return "{\n" + lines.joined(separator: ",\n") + "\n}\n"
    }

    private static func value(_ v: Any) throws -> String {
        if let region = LabelSchema.region(from: v) { return format(region) }
        if let array = v as? [Any], !array.isEmpty, array.allSatisfy({ LabelSchema.region(from: $0) != nil }) {
            return "[\n" + array.map { "    " + format(LabelSchema.region(from: $0)!) }.joined(separator: ",\n") + "\n  ]"
        }
        return try fragment(v)
    }

    private static func fragment(_ v: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: v,
                                              options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }

    private static func format(_ r: Region) -> String {
        func n(_ d: Double) -> String { d == d.rounded() ? String(Int(d)) : "\(d)" }
        return "{\"x\": \(n(r.x)), \"y\": \(n(r.y)), \"w\": \(n(r.w)), \"h\": \(n(r.h))}"
    }
}

public enum LabelFileError: Error, CustomStringConvertible {
    case notAnObject(String)
    public var description: String {
        switch self { case .notAnObject(let name): "\(name): top level must be a JSON object" }
    }
}
