import Foundation
import LookKit
import UIKit

/// Which look is selected and how strong, remembered on the device (Hikâye 1.4, karar 3: per look).
@MainActor @Observable
final class LookSelection {
    let strip: [LookRecipe]
    private let catalog: LookCatalog?
    private let defaults: UserDefaults
    private(set) var strengths: [String: Double]

    var selectedID: String {
        didSet { if selectedID != oldValue { defaults.set(selectedID, forKey: Keys.selected) } }
    }

    static let defaultStrength = 1.0
    private enum Keys {
        static let selected = "look.selected"
        static let strengths = "look.strengths"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let catalog = try? LookCatalog.bundled()
        self.catalog = catalog
        strip = catalog?.strip ?? [.natural]
        strengths = defaults.dictionary(forKey: Keys.strengths) as? [String: Double] ?? [:]
        let saved = defaults.string(forKey: Keys.selected)
        selectedID = strip.contains(where: { $0.id == saved }) ? saved! : LookRecipe.natural.id
    }

    var selected: LookRecipe { strip.first { $0.id == selectedID } ?? .natural }
    var isNatural: Bool { selectedID == LookRecipe.natural.id }

    var strength: Double {
        get { isNatural ? 0 : strengths[selectedID] ?? Self.defaultStrength }
        set {
            guard !isNatural else { return }
            strengths[selectedID] = min(1, max(0, newValue))
            defaults.set(strengths, forKey: Keys.strengths)
        }
    }

    /// Small example image for the strip; nil for "Doğal".
    func sample(for look: LookRecipe) -> UIImage? {
        catalog?.sampleURL(for: look).flatMap { UIImage(contentsOfFile: $0.path) }
    }

    func name(of look: LookRecipe) -> String {
        look.name.text(for: Locale.current.language.languageCode?.identifier)
    }
}
