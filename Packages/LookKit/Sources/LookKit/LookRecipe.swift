import Foundation

/// A look as data (spec 03, Constitution III). Presets, packs and user references all produce this format;
/// the camera and rendering never look at where it came from (`source`).
public struct LookRecipe: Codable, Sendable, Hashable, Identifiable {
    public static let currentFormat = 1

    public var format: Int
    public var id: String
    /// Recipe content version; bumped whenever the look changes.
    public var version: Int
    public var name: LocalizedText
    public var summary: LocalizedText
    public var category: String
    /// Scene types (spec 04 list) the look was designed for.
    public var sceneTypes: [String]
    public var adjustments: LookAdjustments
    public var blur: BlurRequest
    /// Optional bias for the exposure decision (spec 02 FR-004). Empty in MVP recipes.
    public var exposureBias: Double?
    /// Optional composition template id (spec 04).
    public var compositionTemplate: String?
    /// Optional lighting advice keys (spec 04).
    public var lightingAdvice: [String]?
    public var sample: SampleImage?
    public var access: AccessLevel
    public var source: RecipeSource

    public enum BlurRequest: String, Codable, Sendable, CaseIterable { case none, light, strong }
    public enum AccessLevel: String, Codable, Sendable { case free, premium }
    public enum RecipeSource: String, Codable, Sendable { case bundled, pack, userReference }

    public init(format: Int = LookRecipe.currentFormat, id: String, version: Int, name: LocalizedText, summary: LocalizedText,
                category: String, sceneTypes: [String] = [], adjustments: LookAdjustments, blur: BlurRequest = .none,
                exposureBias: Double? = nil, compositionTemplate: String? = nil, lightingAdvice: [String]? = nil,
                sample: SampleImage? = nil, access: AccessLevel = .free, source: RecipeSource = .bundled) {
        self.format = format; self.id = id; self.version = version; self.name = name; self.summary = summary
        self.category = category; self.sceneTypes = sceneTypes; self.adjustments = adjustments; self.blur = blur
        self.exposureBias = exposureBias; self.compositionTemplate = compositionTemplate; self.lightingAdvice = lightingAdvice
        self.sample = sample; self.access = access; self.source = source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(Int.self, forKey: .format)
        id = try c.decode(String.self, forKey: .id)
        version = try c.decode(Int.self, forKey: .version)
        name = try c.decode(LocalizedText.self, forKey: .name)
        summary = try c.decodeIfPresent(LocalizedText.self, forKey: .summary) ?? LocalizedText(tr: "", en: "")
        category = try c.decode(String.self, forKey: .category)
        sceneTypes = try c.decodeIfPresent([String].self, forKey: .sceneTypes) ?? []
        adjustments = try c.decodeIfPresent(LookAdjustments.self, forKey: .adjustments) ?? .zero
        blur = try c.decodeIfPresent(BlurRequest.self, forKey: .blur) ?? .none
        exposureBias = try c.decodeIfPresent(Double.self, forKey: .exposureBias)
        compositionTemplate = try c.decodeIfPresent(String.self, forKey: .compositionTemplate)
        lightingAdvice = try c.decodeIfPresent([String].self, forKey: .lightingAdvice)
        sample = try c.decodeIfPresent(SampleImage.self, forKey: .sample)
        access = try c.decodeIfPresent(AccessLevel.self, forKey: .access) ?? .free
        source = try c.decodeIfPresent(RecipeSource.self, forKey: .source) ?? .bundled
    }

    /// Decodes and validates. Unknown keys are ignored (forward compatible); unsupported formats are rejected.
    public static func decode(_ data: Data) throws -> LookRecipe {
        let recipe = try JSONDecoder().decode(LookRecipe.self, from: data)
        try recipe.validate()
        return recipe
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public func validate() throws {
        guard format == Self.currentFormat else { throw ValidationError.unsupportedFormat(format) }
        guard !id.trimmingCharacters(in: .whitespaces).isEmpty else { throw ValidationError.invalid("id") }
        guard version >= 1 else { throw ValidationError.invalid("version") }
        guard !name.tr.isEmpty, !name.en.isEmpty else { throw ValidationError.invalid("name") }
        if let field = adjustments.firstOutOfRange() { throw ValidationError.outOfRange(field) }
        if let bias = exposureBias, !(-1...1).contains(bias) { throw ValidationError.outOfRange("exposureBias") }
    }

    public enum ValidationError: Error, Equatable {
        case unsupportedFormat(Int)
        case invalid(String)
        case outOfRange(String)
    }

    /// "Doğal": no look, only the capture baseline (spec 03 Hikâye 1.2). Always first in the strip.
    public static let natural = LookRecipe(
        id: "natural", version: 1,
        name: LocalizedText(tr: "Doğal", en: "Natural"),
        summary: LocalizedText(tr: "Görünüm uygulanmaz", en: "No look applied"),
        category: "any", adjustments: .zero)
}

public struct LocalizedText: Codable, Sendable, Hashable {
    public var tr: String
    public var en: String

    public init(tr: String, en: String) { self.tr = tr; self.en = en }

    /// Turkish for Turkish, English for everything else (Constitution VI).
    public func text(for languageCode: String?) -> String { languageCode == "tr" ? tr : en }
}

public struct SampleImage: Codable, Sendable, Hashable {
    /// File name next to the recipe.
    public var image: String
    public var license: AssetLicense
}

/// License record required for every image that ships (Constitution "İçerik lisansı", FR-009).
public struct AssetLicense: Codable, Sendable, Hashable {
    public var source: String
    /// e.g. "own", "purchased", "placeholder-generated".
    public var type: String
    public var attribution: String?
    /// ISO date the license was recorded.
    public var date: String
}
