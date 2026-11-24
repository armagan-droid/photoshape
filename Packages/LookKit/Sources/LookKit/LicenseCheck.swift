import Foundation

/// No image without a license record enters a build (spec 03 FR-009, Constitution "İçerik lisansı").
/// Checks a looks folder: every image file must be the sample of a recipe with a complete license record.
/// For a release build, placeholder images are refused too (spec 03 açık soru 1: no App Store with placeholders).
public enum LicenseCheck {
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "webp"]
    public static let placeholderType = "placeholder-generated"

    public static func problems(in directory: URL, release: Bool) -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var licensed: [String: AssetLicense] = [:], problems: [String] = []
        let decoder = JSONDecoder()
        for file in files where file.lastPathComponent.hasSuffix(".look.json") {
            guard let data = try? Data(contentsOf: file), let look = try? decoder.decode(LookRecipe.self, from: data) else {
                problems.append("\(file.lastPathComponent): unreadable recipe")
                continue
            }
            guard let sample = look.sample else { continue }
            let l = sample.license
            if l.source.isEmpty || l.type.isEmpty || l.date.isEmpty {
                problems.append("\(sample.image): incomplete license record in \(file.lastPathComponent)")
            }
            licensed[sample.image] = l
        }
        for file in files where imageExtensions.contains(file.pathExtension.lowercased()) {
            let name = file.lastPathComponent
            guard let license = licensed[name] else {
                problems.append("\(name): no recipe with a license record names this image")
                continue
            }
            if release, license.type == placeholderType { problems.append("\(name): placeholder image in a release build") }
        }
        for name in licensed.keys where !files.contains(where: { $0.lastPathComponent == name }) {
            problems.append("\(name): named by a recipe but missing")
        }
        return problems.sorted()
    }
}
