import FrameKit
import Foundation

/// How the phone is held against the example's shooting angle (spec 04 FR-001/FR-002 "cihaz eğimi", spec 05 FR-012).
/// Pure: the input is the gravity vector CoreMotion reports, in the phone's own axes (x right, y up, z out of the screen).
public enum PhoneTilt {
    /// Degrees the back camera looks below the horizon: 0 = phone upright, 90 = phone flat, looking straight down.
    /// Nil when the phone is lying screen-down or the reading is not usable.
    public static func downwardAngle(gravityX x: Double, y: Double, z: Double) -> Double? {
        let length = (x * x + y * y + z * z).squareRoot()
        guard length > 0.5 else { return nil }
        // Upright: gravity along −y. Flat with the screen up: gravity along −z (the back camera points at the table).
        let angle = atan2(-z, -y) * 180 / .pi
        return (-10...120).contains(angle) ? min(90, max(0, angle)) : nil
    }

    /// What each example angle wants, with room so the hint does not flicker at the edge.
    static let topDownAtLeast = 60.0
    static let angledFrom = 15.0, angledUpTo = 80.0
    static let eyeLevelUpTo = 40.0

    /// A hint when the phone is clearly held at another angle than the example's, else nil.
    public static func instruction(downward: Double?, example: ShotAngle?) -> GuidanceInstruction? {
        guard let a = downward, let example else { return nil }
        switch example {
        case .topDown where a < topDownAtLeast:
            return GuidanceInstruction(kind: "angle.holdFlat", direction: .down, priority: 0, phraseKey: "guide.angle.holdFlat")
        case .angled where a < angledFrom:
            return GuidanceInstruction(kind: "angle.tipForward", direction: .down, priority: 0, phraseKey: "guide.angle.tipForward")
        case .angled where a > angledUpTo:
            return GuidanceInstruction(kind: "angle.raise", direction: .up, priority: 0, phraseKey: "guide.angle.raise")
        case .eyeLevel where a > eyeLevelUpTo:
            return GuidanceInstruction(kind: "angle.holdUpright", direction: .up, priority: 0, phraseKey: "guide.angle.holdUpright")
        default:
            return nil
        }
    }

    public static let allPhraseKeys = ["holdFlat", "tipForward", "raise", "holdUpright"].map { "guide.angle.\($0)" }
}
