import Foundation

/// Color and tone settings of a look. Unitless: most values are −1…1, amounts are 0…1, 0 means "no change".
/// Physical meaning lives only in `ColorTransform` / `LookRenderer`, so extracted recipes (spec 05) use the same scale.
public struct LookAdjustments: Codable, Sendable, Hashable {
    public var exposure: Double = 0
    public var contrast: Double = 0
    public var highlights: Double = 0
    public var shadows: Double = 0
    /// Lifted blacks (0…1).
    public var fade: Double = 0
    public var temperature: Double = 0
    /// Positive = magenta, negative = green.
    public var tint: Double = 0
    public var saturation: Double = 0
    public var vibrance: Double = 0
    public var ranges: [ColorRange: RangeAdjustment] = [:]
    public var splitTone: SplitTone = .none
    /// 0…1
    public var grain: Double = 0
    /// Darkened corners, 0…1
    public var vignette: Double = 0

    public static let zero = LookAdjustments()

    public init() {}

    public enum ColorRange: String, Codable, Sendable, CaseIterable, CodingKeyRepresentable {
        case red, orange, yellow, green, aqua, blue, purple, magenta

        /// Hue center on 0…1.
        var center: Double {
            switch self {
            case .red: 0
            case .orange: 1.0 / 12
            case .yellow: 1.0 / 6
            case .green: 1.0 / 3
            case .aqua: 1.0 / 2
            case .blue: 2.0 / 3
            case .purple: 3.0 / 4
            case .magenta: 5.0 / 6
            }
        }
    }

    public struct RangeAdjustment: Codable, Sendable, Hashable {
        public var hue: Double = 0
        public var saturation: Double = 0
        public var luminance: Double = 0

        public init(hue: Double = 0, saturation: Double = 0, luminance: Double = 0) {
            self.hue = hue; self.saturation = saturation; self.luminance = luminance
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            hue = try c.decodeIfPresent(Double.self, forKey: .hue) ?? 0
            saturation = try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 0
            luminance = try c.decodeIfPresent(Double.self, forKey: .luminance) ?? 0
        }
    }

    /// Color added to shadows and highlights. Hues 0…1, amounts 0…1.
    public struct SplitTone: Codable, Sendable, Hashable {
        public var shadowHue: Double = 0
        public var shadowAmount: Double = 0
        public var highlightHue: Double = 0
        public var highlightAmount: Double = 0

        public static let none = SplitTone()
        public init(shadowHue: Double = 0, shadowAmount: Double = 0, highlightHue: Double = 0, highlightAmount: Double = 0) {
            self.shadowHue = shadowHue; self.shadowAmount = shadowAmount
            self.highlightHue = highlightHue; self.highlightAmount = highlightAmount
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            shadowHue = try c.decodeIfPresent(Double.self, forKey: .shadowHue) ?? 0
            shadowAmount = try c.decodeIfPresent(Double.self, forKey: .shadowAmount) ?? 0
            highlightHue = try c.decodeIfPresent(Double.self, forKey: .highlightHue) ?? 0
            highlightAmount = try c.decodeIfPresent(Double.self, forKey: .highlightAmount) ?? 0
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v(_ k: CodingKeys) throws -> Double { try c.decodeIfPresent(Double.self, forKey: k) ?? 0 }
        exposure = try v(.exposure); contrast = try v(.contrast); highlights = try v(.highlights); shadows = try v(.shadows)
        fade = try v(.fade); temperature = try v(.temperature); tint = try v(.tint)
        saturation = try v(.saturation); vibrance = try v(.vibrance); grain = try v(.grain); vignette = try v(.vignette)
        ranges = try c.decodeIfPresent([ColorRange: RangeAdjustment].self, forKey: .ranges) ?? [:]
        splitTone = try c.decodeIfPresent(SplitTone.self, forKey: .splitTone) ?? .none
    }

    /// The look at a given strength (0 = no change, 1 = full). Hues of split toning do not scale, amounts do.
    public func scaled(by s: Double) -> LookAdjustments {
        if s == 1 { return self }
        var a = LookAdjustments()
        a.exposure = exposure * s; a.contrast = contrast * s; a.highlights = highlights * s; a.shadows = shadows * s
        a.fade = fade * s; a.temperature = temperature * s; a.tint = tint * s
        a.saturation = saturation * s; a.vibrance = vibrance * s; a.grain = grain * s; a.vignette = vignette * s
        for (range, r) in ranges where s != 0 {
            a.ranges[range] = RangeAdjustment(hue: r.hue * s, saturation: r.saturation * s, luminance: r.luminance * s)
        }
        if s != 0, splitTone != .none {
            a.splitTone = SplitTone(shadowHue: splitTone.shadowHue, shadowAmount: splitTone.shadowAmount * s,
                                    highlightHue: splitTone.highlightHue, highlightAmount: splitTone.highlightAmount * s)
        }
        return a
    }

    /// False when the per-pixel color transform is the identity (only grain/vignette or nothing set).
    var hasPointwiseChange: Bool { !isEffectivelyZero }

    private var isEffectivelyZero: Bool {
        [exposure, contrast, highlights, shadows, fade, temperature, tint, saturation, vibrance].allSatisfy { $0 == 0 }
            && ranges.values.allSatisfy { $0 == RangeAdjustment() }
            && splitTone.shadowAmount == 0 && splitTone.highlightAmount == 0
    }

    func firstOutOfRange() -> String? {
        let signed: [(String, Double)] = [("exposure", exposure), ("contrast", contrast), ("highlights", highlights),
                                          ("shadows", shadows), ("temperature", temperature), ("tint", tint),
                                          ("saturation", saturation), ("vibrance", vibrance)]
        for (k, v) in signed where !(-1...1).contains(v) { return k }
        let unit: [(String, Double)] = [("fade", fade), ("grain", grain), ("vignette", vignette),
                                        ("splitTone.shadowHue", splitTone.shadowHue), ("splitTone.shadowAmount", splitTone.shadowAmount),
                                        ("splitTone.highlightHue", splitTone.highlightHue), ("splitTone.highlightAmount", splitTone.highlightAmount)]
        for (k, v) in unit where !(0...1).contains(v) { return k }
        for (range, r) in ranges {
            for (k, v) in [("hue", r.hue), ("saturation", r.saturation), ("luminance", r.luminance)] where !(-1...1).contains(v) {
                return "ranges.\(range.rawValue).\(k)"
            }
        }
        return nil
    }
}
