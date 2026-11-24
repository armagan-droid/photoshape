import CoreGraphics
import Foundation
import LookKit

/// White balance that leaves some of a warm room's warmth (spec 02 FR-003, Hikâye 3).
///
/// iOS cannot shift its auto white balance, and locking it would stop following the light. So the camera keeps
/// its auto white balance, and the app gives back part of the warmth it removed, as the look's `temperature`.
/// The look is applied to both the preview and the saved photo, so they stay the same (FR-005).
/// Pure: the input is the light the camera's auto white balance corrected for, in kelvin.
public enum WhiteBalanceDecider {
    /// Share of the warm light's color the photo keeps, in mired (the usual white balance scale). 0 = fully neutral.
    /// The value can be tuned (FR-003, open question 1). It starts low because iOS already leaves a little warmth;
    /// with it a 4000 K light looks like 5950 K, a 4500 K one like 6100 K.
    public static let keptWarmth = 0.15
    /// Light cooler than this is corrected fully (FR-003 is about warm light only).
    static let noWarmthFrom = 5000.0
    /// Full `keptWarmth` from this light down; in between it rises smoothly, so a slowly changing light never jumps.
    static let fullWarmthFrom = 4000.0
    /// Leaves room for a recipe's own warmth on the −1…1 scale. Lamps below about 3700 K reach it.
    public static let maxWarmth = 0.8
    static let daylight = 6504.0

    /// Look `temperature` (0…`maxWarmth`) to add for a scene the camera corrected for `cameraKelvin`.
    /// Zero for daylight, cool light or when the camera does not say.
    public static func warmth(cameraKelvin: Double?) -> Double {
        guard let k = cameraKelvin, k.isFinite, k > 0 else { return 0 }
        let mired = 1e6 / k, from = 1e6 / noWarmthFrom, full = 1e6 / fullWarmthFrom
        let weight = min(1, max(0, (mired - from) / (full - from)))
        guard weight > 0 else { return 0 }
        // The light the photo should look lit by: `keptWarmth` of the way from daylight to the real light.
        let dayMired = 1e6 / daylight
        let looksLike = 1e6 / (dayMired + keptWarmth * weight * (mired - dayMired))
        let ratio = redBlueRatio(looksLike) / redBlueRatio(daylight)
        return min(maxWarmth, max(0, temperature(forRatio: ratio)))
    }

    /// Look `temperature` whose red and blue gains (`ColorTransform`: 1 ± 0.1 t) have this ratio.
    static func temperature(forRatio q: Double) -> Double { 10 * (q - 1) / (q + 1) }

    /// Linear-sRGB red/blue of a blackbody light (Kim et al. 2002 Planckian locus, 1667–25000 K).
    static func redBlueRatio(_ kelvin: Double) -> Double {
        let t = min(25000, max(1667, kelvin))
        let x = t <= 4000
            ? -0.2661239e9 / (t * t * t) - 0.2343589e6 / (t * t) + 0.8776956e3 / t + 0.179910
            : -3.0258469e9 / (t * t * t) + 2.1070379e6 / (t * t) + 0.2226347e3 / t + 0.240390
        let y: Double
        if t <= 2222 {
            y = -1.1063814 * x * x * x - 1.34811020 * x * x + 2.18555832 * x - 0.20219683
        } else if t <= 4000 {
            y = -0.9549476 * x * x * x - 1.37418593 * x * x + 2.09137015 * x - 0.16748867
        } else {
            y = 3.0817580 * x * x * x - 5.87338670 * x * x + 3.75112997 * x - 0.37001483
        }
        let X = x / y, Y = 1.0, Z = (1 - x - y) / y
        let r = 3.2406 * X - 1.5372 * Y - 0.4986 * Z
        let b = 0.0557 * X - 0.2040 * Y + 1.0570 * Z
        return r / max(b, 1e-6)
    }
}

// MARK: - Mixed light (spec 02 Hikâye 3.2, FR-007)

extension WhiteBalanceDecider {
    public struct MixedLight: Sendable, Hashable {
        /// Mean b* (yellow +, blue −) of the bright, nearly gray surfaces on the subject and around it.
        public var subjectCast: Double
        public var surroundCast: Double
        /// The subject is lit by another color of light than the rest (window on one side, lamp on the other).
        public var isMixed: Bool
        /// Mean color (gamma sRGB) of the subject's nearly gray surfaces.
        public var subjectColor: SIMD3<Double>
    }

    /// b* difference between subject and surroundings that counts as two kinds of light.
    static let mixedDifference = 8.0

    /// Reads the color of the light on the subject against the rest, from the frame before the look.
    /// Nil when there are too few nearly gray surfaces to tell.
    public static func mixedLight(colors: [SIMD3<Double>], width: Int, height: Int, subject: CGRect) -> MixedLight? {
        guard colors.count == width * height, width > 0 else { return nil }
        var inside: [Double] = [], outside: [Double] = [], insideColor = SIMD3<Double>(0, 0, 0)
        for y in 0..<height {
            for x in 0..<width {
                let lab = ColorScience.lab(fromSRGB: (colors[y * width + x].x, colors[y * width + x].y, colors[y * width + x].z))
                // Whites and light grays: under a lamp they turn yellow (b* up to ~35) but stay off the red–green axis;
                // orange food has a clearly positive a* and is left out.
                guard lab.l > 45, abs(lab.a) < 10, abs(lab.b) < 40 else { continue }
                let p = CGPoint(x: (Double(x) + 0.5) / Double(width), y: (Double(y) + 0.5) / Double(height))
                if subject.contains(p) { inside.append(lab.b); insideColor += colors[y * width + x] } else { outside.append(lab.b) }
            }
        }
        guard inside.count >= 4, outside.count >= 8 else { return nil }
        let s = inside.reduce(0, +) / Double(inside.count), o = outside.reduce(0, +) / Double(outside.count)
        return MixedLight(subjectCast: s, surroundCast: o, isMixed: abs(s - o) > mixedDifference,
                          subjectColor: insideColor / Double(inside.count))
    }

    /// Share of the subject's own cast that is removed in mixed light; the rest stays, like FR-003's warmth.
    static let mixedCorrection = 0.7

    /// White balance gains for a mixed-light scene: they follow the subject (Hikâye 3.2), the background may keep
    /// its other color. Neutral when the light is not mixed. The gains are found on the subject's own gray
    /// surfaces, so a lamp-yellow plate ends up only slightly warm.
    public static func gains(for mixed: MixedLight?) -> ChannelGains {
        guard let mixed, mixed.isMixed else { return .neutral }
        let target = mixed.subjectCast * (1 - mixedCorrection)
        func b(_ k: Double) -> Double {
            let c = ChannelGains(coolingRatio: k).apply(mixed.subjectColor)
            return ColorScience.lab(fromSRGB: (c.x, c.y, c.z)).b
        }
        // b* falls as k grows (more blue, less red): bisection in log space.
        var lo = log(0.25), hi = log(4.0)
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            if b(exp(mid)) > target { lo = mid } else { hi = mid }
        }
        return ChannelGains(coolingRatio: exp((lo + hi) / 2))
    }
}
