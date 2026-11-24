import Foundation
import ImageIO
import LookKit

/// How the example was shot, from the photo's own camera data (spec 05 Hikâye 8, FR-018, FR-019).
/// Only these fields are read; location, dates and serial numbers are never read or kept.
/// Screenshots and downloaded copies carry no camera data: then there are no settings at all.
public struct ExampleSettings: Codable, Sendable, Hashable {
    /// Seconds.
    public var exposureTime: Double?
    public var fNumber: Double?
    public var iso: Int?
    /// Real focal length in mm and its 35 mm film equivalent.
    public var focalLength: Double?
    public var focalLength35: Double?
    /// Exposure compensation the photographer dialed in, in EV.
    public var exposureBias: Double?
    public var flashFired: Bool?
    /// "iPhone 15 Pro", "X-T5".
    public var cameraModel: String?

    public init(exposureTime: Double? = nil, fNumber: Double? = nil, iso: Int? = nil, focalLength: Double? = nil,
                focalLength35: Double? = nil, exposureBias: Double? = nil, flashFired: Bool? = nil, cameraModel: String? = nil) {
        self.exposureTime = exposureTime; self.fNumber = fNumber; self.iso = iso; self.focalLength = focalLength
        self.focalLength35 = focalLength35; self.exposureBias = exposureBias; self.flashFired = flashFired
        self.cameraModel = cameraModel
    }

    /// From an image's property dictionary (`CGImageSourceCopyPropertiesAtIndex`). Nil when the photo has no
    /// shooting values (no shutter, aperture or ISO): a screenshot or a stripped copy.
    public init?(properties: [String: Any]) {
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        func number(_ key: CFString) -> Double? { (exif[key as String] as? NSNumber)?.doubleValue }
        let iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first?.intValue
        let flash = (exif[kCGImagePropertyExifFlash as String] as? NSNumber).map { $0.intValue & 1 == 1 }
        let model = (tiff[kCGImagePropertyTIFFModel as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(exposureTime: number(kCGImagePropertyExifExposureTime).flatMap { $0 > 0 ? $0 : nil },
                  fNumber: number(kCGImagePropertyExifFNumber).flatMap { $0 > 0 ? $0 : nil },
                  iso: iso.flatMap { $0 > 0 ? $0 : nil },
                  focalLength: number(kCGImagePropertyExifFocalLength).flatMap { $0 > 0 ? $0 : nil },
                  focalLength35: number(kCGImagePropertyExifFocalLenIn35mmFilm).flatMap { $0 > 0 ? $0 : nil },
                  exposureBias: number(kCGImagePropertyExifExposureBiasValue),
                  flashFired: flash,
                  cameraModel: model?.isEmpty == false ? model : nil)
        guard exposureTime != nil || fNumber != nil || iso != nil else { return nil }
    }

    // MARK: - What each value did to the photo (Hikâye 8.4): explanation keys

    public var shutterExplanation: String? {
        exposureTime.map { t in
            t <= 1.0 / 500 ? "settings.explain.shutter.frozen"
                : t <= 1.0 / 60 ? "settings.explain.shutter.handheld"
                : t <= 1.0 / 8 ? "settings.explain.shutter.slow" : "settings.explain.shutter.long"
        }
    }

    /// Phone lenses have a fixed aperture and tiny sensors: f/1.8 there does not mean a blurred background.
    public var isPhone: Bool { (focalLength ?? 100) < 12 }

    public var apertureExplanation: String? {
        fNumber.map { f in
            isPhone ? "settings.explain.aperture.phone"
                : f <= 2.8 ? "settings.explain.aperture.wide"
                : f <= 8 ? "settings.explain.aperture.mid" : "settings.explain.aperture.deep"
        }
    }

    public var isoExplanation: String? {
        iso.map { $0 <= 200 ? "settings.explain.iso.low" : $0 <= 1600 ? "settings.explain.iso.mid" : "settings.explain.iso.high" }
    }

    /// Which of the app's lens buttons this focal length is closest to.
    public var lensKey: String? {
        focalLength35.map { $0 < 20 ? "settings.lens.wide" : $0 < 35 ? "settings.lens.normal" : "settings.lens.close" }
    }

    public var biasExplanation: String? {
        exposureBias.map { $0 > 0.3 ? "settings.explain.bias.up" : $0 < -0.3 ? "settings.explain.bias.down" : "settings.explain.bias.none" }
    }

    public var flashKey: String? { flashFired.map { $0 ? "settings.flash.fired" : "settings.flash.off" } }

    /// "1/125" below a second, "2.5" above (seconds unit added by the screen).
    public static func shutterText(_ t: Double) -> String {
        if t >= 1 { return t == t.rounded() ? String(Int(t)) : String(format: "%.1f", t) }
        return "1/\(Int((1 / t).rounded()))"
    }

    public static var allKeys: [String] {
        ["frozen", "handheld", "slow", "long"].map { "settings.explain.shutter.\($0)" }
            + ["phone", "wide", "mid", "deep"].map { "settings.explain.aperture.\($0)" }
            + ["low", "mid", "high"].map { "settings.explain.iso.\($0)" }
            + ["wide", "normal", "close"].map { "settings.lens.\($0)" }
            + ["up", "down", "none"].map { "settings.explain.bias.\($0)" }
            + ["settings.flash.fired", "settings.flash.off"]
    }
}

/// Approximate values read from the picture itself; available for every example, screenshots too
/// (spec 05 FR-020). Built from the same statistics as `ExampleReading`, so the numbers and sentences agree.
public struct ExampleMeasurements: Sendable, Hashable {
    /// Mean brightness against mid-gray, EV, rounded to a third.
    public var brightnessEV: Double
    /// Bright end (95th percentile) to dark end (5th), in stops, rounded to a half.
    public var contrastStops: Double
    /// 0–1. Nil in examples saved before 2026-11-23 (FR-023).
    public var highlightClip: Double?
    public var shadowClip: Double?
    /// Apparent color temperature of the gray parts, K, rounded to 100. Nil without gray parts.
    public var colorTemperature: Double?
    public var tintKey: String?

    public init(stats: ColorStats) {
        brightnessEV = Self.thirds(log2(Self.luminance(stats.meanL) / Self.midGray))
        contrastStops = (log2(max(Self.luminance(stats.highL), 0.002) / max(Self.luminance(stats.lowL), 0.002)) * 2).rounded() / 2
        highlightClip = stats.highlightClip
        shadowClip = stats.shadowClip
        colorTemperature = stats.neutralB.map { b in (Self.correlatedColorTemperature(a: stats.neutralA ?? 0, b: b) / 100).rounded() * 100 }
        tintKey = stats.neutralA.flatMap { $0 < -2 ? "settings.tint.green" : $0 > 2 ? "settings.tint.magenta" : nil }
        temperatureKey = stats.neutralB.map { b in
            // Same thresholds as the card's color sentence (ExampleReading.color).
            b > 8 ? "settings.explain.temperature.lamp" : b > 2 ? "settings.explain.temperature.warm"
                : b < -2 ? "settings.explain.temperature.cool" : "settings.explain.temperature.neutral"
        }
    }

    public var temperatureKey: String?

    public var brightnessKey: String {
        brightnessEV > 0.3 ? "settings.explain.brightness.bright" : brightnessEV < -0.3 ? "settings.explain.brightness.dark"
            : "settings.explain.brightness.mid"
    }

    public var contrastKey: String {
        contrastStops > 7.5 ? "settings.explain.contrast.high" : contrastStops < 4.5 ? "settings.explain.contrast.low"
            : "settings.explain.contrast.mid"
    }

    public var highlightKey: String? { highlightClip.map { $0 >= 0.02 ? "settings.explain.highlights.blown" : "settings.explain.highlights.fine" } }
    public var shadowKey: String? { shadowClip.map { $0 >= 0.02 ? "settings.explain.shadows.crushed" : "settings.explain.shadows.fine" } }

    public static var allKeys: [String] {
        ["bright", "dark", "mid"].map { "settings.explain.brightness.\($0)" }
            + ["high", "low", "mid"].map { "settings.explain.contrast.\($0)" }
            + ["blown", "fine"].map { "settings.explain.highlights.\($0)" }
            + ["crushed", "fine"].map { "settings.explain.shadows.\($0)" }
            + ["lamp", "warm", "cool", "neutral"].map { "settings.explain.temperature.\($0)" }
            + ["settings.tint.green", "settings.tint.magenta"]
    }

    // MARK: - Color science

    static let midGray = 0.184 // Y of L* = 50

    static func luminance(_ l: Double) -> Double {
        l > 8 ? pow((l + 16) / 116, 3) : l / 903.3
    }

    static func thirds(_ v: Double) -> Double { (v * 3).rounded() / 3 }

    /// The gray parts' color as a light source: Lab (L 70, D65 white) → xy → McCamy's approximation.
    /// A neutral gray reads ≈ 6500 K, the white point of the screen.
    static func correlatedColorTemperature(a: Double, b: Double, l: Double = 70) -> Double {
        let fy = (l + 16) / 116, fx = fy + a / 500, fz = fy - b / 200
        func inv(_ t: Double) -> Double { t > 6.0 / 29 ? t * t * t : 3 * pow(6.0 / 29, 2) * (t - 4.0 / 29) }
        let x = 0.95047 * inv(fx), y = inv(fy), z = 1.08883 * inv(fz)
        let sum = x + y + z
        let cx = x / sum, cy = y / sum
        let n = (cx - 0.3320) / (0.1858 - cy)
        return min(20_000, max(1_500, 449 * n * n * n + 3525 * n * n + 6823.3 * n + 5520.33))
    }
}
