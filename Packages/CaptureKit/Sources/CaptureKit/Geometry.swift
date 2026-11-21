/// Rectangle in normalized coordinates: 0–1, origin top-left, in the displayed (upright) orientation.
public struct NormalizedRect: Codable, Sendable, Hashable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    public static let full = NormalizedRect(x: 0, y: 0, w: 1, h: 1)
}

/// Integer pixel rectangle, origin top-left.
public struct PixelRect: Sendable, Hashable {
    public var x: Int
    public var y: Int
    public var w: Int
    public var h: Int
}

/// The 4:5 portrait output frame (FR-002). The preview overlay and the saved crop both come from here,
/// so what the user sees in the frame is exactly what gets saved.
public enum CropGeometry {
    /// Output aspect as width : height.
    public static let aspectWidth = 4
    public static let aspectHeight = 5

    /// Largest centered 4:5 crop of an upright image, in whole pixels, with `w * 5 == h * 4` exactly.
    public static func pixelCrop(width: Int, height: Int) -> PixelRect {
        fit(inside: PixelRect(x: 0, y: 0, w: width, h: height))
    }

    /// The same crop in normalized coordinates for an image of the given aspect (e.g. 3:4 sensor frame).
    /// Used to draw the preview frame before any pixel exists.
    public static func normalizedCrop(aspectWidth w: Double, aspectHeight h: Double) -> NormalizedRect {
        let target = Double(aspectWidth) / Double(aspectHeight)
        if w / h <= target {
            let ch = (w / target) / h
            return NormalizedRect(x: 0, y: (1 - ch) / 2, w: 1, h: ch)
        } else {
            let cw = (h * target) / w
            return NormalizedRect(x: (1 - cw) / 2, y: 0, w: cw, h: 1)
        }
    }

    /// The pixel crop described by `rect` in an image of the given size, shrunk (centered) so that it is an
    /// exact 4:5 rectangle of whole pixels inside `rect`.
    public static func snap(_ rect: NormalizedRect, width: Int, height: Int) -> PixelRect {
        let eps = 1e-6
        let x0 = max(0, Int((rect.x * Double(width) - eps).rounded(.up)))
        let y0 = max(0, Int((rect.y * Double(height) - eps).rounded(.up)))
        let x1 = min(width, Int(((rect.x + rect.w) * Double(width) + eps).rounded(.down)))
        let y1 = min(height, Int(((rect.y + rect.h) * Double(height) + eps).rounded(.down)))
        return fit(inside: PixelRect(x: x0, y: y0, w: max(0, x1 - x0), h: max(0, y1 - y0)))
    }

    private static func fit(inside r: PixelRect) -> PixelRect {
        // Largest k with 4k ≤ w and 5k ≤ h.
        let k = min(r.w / aspectWidth, r.h / aspectHeight)
        let w = k * aspectWidth, h = k * aspectHeight
        return PixelRect(x: r.x + (r.w - w) / 2, y: r.y + (r.h - h) / 2, w: w, h: h)
    }
}
