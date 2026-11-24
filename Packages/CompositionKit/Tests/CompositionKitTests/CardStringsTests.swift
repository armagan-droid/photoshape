import Foundation
import Testing
@testable import CompositionKit

/// SC-011: every sentence the card can show exists in Turkish and English, and stays short (Constitution VI).
@Suite("Example card sentences (spec 05 FR-015, SC-011)")
struct CardStringsTests {
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() // CompositionKit
        .deletingLastPathComponent().deletingLastPathComponent() // repo root
        .appendingPathComponent("App/photoshape/Localizable.xcstrings")

    static func catalog() throws -> [String: [String: String]] {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        let strings = try #require(json?["strings"] as? [String: Any])
        var out: [String: [String: String]] = [:]
        for (key, entry) in strings {
            let locs = (entry as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            out[key] = locs.compactMapValues { (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String }
        }
        return out
    }

    static func words(_ s: String) -> Int {
        s.split { $0.isWhitespace }.filter { $0.contains { $0.isLetter } }.count
    }

    /// Spec 04 FR-K6: guidance sentences in both languages, at most 6 words.
    @Test func guideSentencesAreShortInBothLanguages() throws {
        let catalog = try Self.catalog()
        for key in CompositionGuide.allPhraseKeys {
            for lang in ["tr", "en"] {
                let text = catalog[key]?[lang] ?? ""
                #expect(!text.isEmpty, "\(key) \(lang) missing")
                #expect(Self.words(text) <= 6, "\(key) \(lang): \(text)")
            }
        }
    }

    @Test func everyKeyHasTurkishAndEnglish() throws {
        let catalog = try Self.catalog()
        let keys = ExampleReading.allPhraseKeys + ExampleReading.topicTitleKeys
            + ["card.title", "card.steps", "card.start", "card.change", "card.none"]
            + ExampleSettings.allKeys + ExampleMeasurements.allKeys
            + ["title", "real", "estimated", "noCameraData", "yourCameraNow", "shutter", "aperture", "iso", "focal", "bias",
               "flash", "device", "brightness", "contrast", "highlights", "shadows", "temperature", "tint"].map { "settings.\($0)" }
            + ["settings.unit.seconds %@", "settings.unit.stops %@", "settings.yourCamera %@", "settings.appAdjustment %@"]
        for key in keys {
            let entry = catalog[key] ?? [:]
            #expect(!(entry["tr"] ?? "").isEmpty, "\(key): Turkish missing")
            #expect(!(entry["en"] ?? "").isEmpty, "\(key): English missing")
        }
    }

    @Test func stepsAndLinesAreShort() throws {
        let catalog = try Self.catalog()
        for key in ExampleReading.allPhraseKeys + ExampleSettings.allKeys + ExampleMeasurements.allKeys {
            for (lang, text) in catalog[key] ?? [:] {
                #expect(Self.words(text) <= 6, "\(key) [\(lang)]: \"\(text)\" has \(Self.words(text)) words")
            }
        }
    }
}
