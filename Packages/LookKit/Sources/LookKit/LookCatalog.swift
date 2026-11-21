import Foundation

/// Looks available in the strip (FR-004). Files that cannot be read or have an unsupported format are
/// skipped, never fatal (spec 03 uç durum "bozuk tarif").
public struct LookCatalog: Sendable {
    public let directory: URL
    /// Valid looks in file-name order (`01-…`, `02-…`).
    public let looks: [LookRecipe]
    /// File name and reason for every skipped file.
    public let rejected: [(file: String, reason: String)]

    /// "Doğal" first, then the looks (Hikâye 1.2, karar 4).
    public var strip: [LookRecipe] { [.natural] + looks }

    public init(directory: URL) {
        self.directory = directory
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasSuffix(".look.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var looks: [LookRecipe] = []
        var rejected: [(String, String)] = []
        for file in files {
            do {
                let recipe = try LookRecipe.decode(Data(contentsOf: file))
                if looks.contains(where: { $0.id == recipe.id }) || recipe.id == LookRecipe.natural.id {
                    rejected.append((file.lastPathComponent, "duplicate id \(recipe.id)"))
                } else {
                    looks.append(recipe)
                }
            } catch {
                rejected.append((file.lastPathComponent, "\(error)"))
            }
        }
        self.looks = looks
        self.rejected = rejected
    }

    /// The looks that ship with the app.
    public static func bundled() throws -> LookCatalog {
        guard let url = Bundle.module.url(forResource: "Looks", withExtension: nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return LookCatalog(directory: url)
    }

    public func sampleURL(for recipe: LookRecipe) -> URL? {
        guard let name = recipe.sample?.image else { return nil }
        let url = directory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
