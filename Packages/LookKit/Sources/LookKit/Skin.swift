import Foundation

/// Keeps people's skin out of the example's color statistics (spec 05 FR-004, Hikâye 4): a warm-skinned portrait
/// must not turn the user's latte orange. Native alternative (FR-004 d): a cell counts as skin when it is inside
/// Vision's person mask *and* skin-colored. Skin color alone is not enough (coffee, wood and bread share it);
/// the mask alone is not enough either (it covers clothes and hair). Pure; the mask is computed by the caller.
public enum SkinTone {
    /// Skin-like color, light to dark skin, in YCbCr of gamma-encoded sRGB (0…1 input).
    public static func isSkinColor(_ c: SIMD3<Double>) -> Bool {
        let r = c.x * 255, g = c.y * 255, b = c.z * 255
        let y = 0.299 * r + 0.587 * g + 0.114 * b
        let cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
        let cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b
        return y > 35 && (77...127).contains(cb) && (133...173).contains(cr)
    }

    /// Cells to leave out of the statistics: skin-colored cells where the person mask (same grid, 0…1) is ≥ 0.5.
    public static func skinCells(colors: [SIMD3<Double>], personMask: [Float]) -> [Bool] {
        guard personMask.count == colors.count else { return Array(repeating: false, count: colors.count) }
        return zip(colors, personMask).map { color, mask in mask >= 0.5 && isSkinColor(color) }
    }

    /// At least this share of the picture must remain, or the statistics would describe too little of it.
    static let minimumKept = 0.25
}

extension ReferenceProfile {
    /// The profile without the excluded cells (spec 05 FR-004). When too little would remain, nothing is left out.
    public init(sample: SceneSample, excluding excluded: [Bool]?) {
        guard let excluded, excluded.count == sample.colors.count, excluded.contains(true) else {
            self.init(sample: sample)
            return
        }
        let kept = zip(sample.colors, excluded).compactMap { $1 ? nil : $0 }
        guard Double(kept.count) >= SkinTone.minimumKept * Double(sample.colors.count) else {
            self.init(sample: sample)
            return
        }
        self.init(sample: SceneSample(colors: kept, cornerRatio: sample.cornerRatio))
    }
}
