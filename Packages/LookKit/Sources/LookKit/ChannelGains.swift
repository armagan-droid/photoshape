import Foundation

/// White balance applied before the look, in linear light (spec 02 Hikâye 3.2). Not part of any recipe: the camera
/// side decides it (mixed light), the renderer applies it to the preview and the saved photo alike (FR-005).
/// Brightness is kept: gains are normalized so luminance does not change for a gray.
public struct ChannelGains: Codable, Sendable, Hashable {
    public var red: Double
    public var blue: Double
    public static let neutral = ChannelGains(red: 1, blue: 1)

    public init(red: Double, blue: Double) { self.red = red; self.blue = blue }

    /// Gains with blue/red ratio `k` (> 1 cools, < 1 warms), split evenly between the two channels.
    public init(coolingRatio k: Double) {
        let s = max(0.25, min(4, k)).squareRoot()
        self.init(red: 1 / s, blue: s)
    }

    public var isNeutral: Bool { abs(red - 1) < 0.005 && abs(blue - 1) < 0.005 }

    var norm: Double { 0.2126 * red + 0.7152 + 0.0722 * blue }

    /// On a gamma-encoded sRGB color (0…1), for tests and for the brain's own estimates.
    public func apply(_ c: SIMD3<Double>) -> SIMD3<Double> {
        func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        func gam(_ v: Double) -> Double { let x = min(1, max(0, v)); return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055 }
        let n = norm
        return SIMD3(gam(lin(c.x) * red / n), gam(lin(c.y) / n), gam(lin(c.z) * blue / n))
    }

    /// Eases toward `target` (live preview: no jumps when the light changes).
    public func blended(toward target: ChannelGains, by k: Double) -> ChannelGains {
        ChannelGains(red: red + (target.red - red) * k, blue: blue + (target.blue - blue) * k)
    }
}
