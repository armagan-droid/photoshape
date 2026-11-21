import CoreGraphics
import Foundation

/// A small, evenly spaced sample of an image's colors (gamma sRGB, 0…1) plus how dark its corners are
/// compared to its center. Taken from the reference once and from the live scene about once a second.
public struct SceneSample: Sendable, Hashable {
    public var colors: [SIMD3<Double>]
    /// Mean luminance of the four corner regions divided by the center region's.
    public var cornerRatio: Double

    public static let gridWidth = 32
    public static let gridHeight = 40

    public init(colors: [SIMD3<Double>], cornerRatio: Double) {
        self.colors = colors
        self.cornerRatio = cornerRatio
    }

    /// Downsamples the image to a small grid (the image is drawn upright, as given).
    public init?(image: CGImage) {
        let w = Self.gridWidth, h = Self.gridHeight
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var colors: [SIMD3<Double>] = []
        colors.reserveCapacity(w * h)
        var corner = 0.0, cornerN = 0.0, center = 0.0, centerN = 0.0
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let c = SIMD3(Double(px[i]), Double(px[i + 1]), Double(px[i + 2])) / 255
                colors.append(c)
                let l = luma(c.x, c.y, c.z)
                let fx = Double(x) / Double(w - 1), fy = Double(y) / Double(h - 1)
                if (fx < 0.15 || fx > 0.85) && (fy < 0.15 || fy > 0.85) { corner += l; cornerN += 1 }
                if abs(fx - 0.5) < 0.2 && abs(fy - 0.5) < 0.2 { center += l; centerN += 1 }
            }
        }
        let ratio = centerN > 0 && cornerN > 0 && center > 0.001 ? (corner / cornerN) / (center / centerN) : 1
        self.init(colors: colors, cornerRatio: ratio)
    }
}

/// The statistics the matcher compares (CIE Lab, L in 0…100).
public struct ColorStats: Codable, Sendable, Hashable {
    public var meanL: Double
    public var stdL: Double
    public var lowL: Double   // 5th percentile
    public var highL: Double  // 95th percentile
    public var meanA: Double
    public var meanB: Double
    public var meanChroma: Double

    public init(colors: [SIMD3<Double>]) {
        var ls: [Double] = [], sumA = 0.0, sumB = 0.0, sumC = 0.0
        ls.reserveCapacity(colors.count)
        for c in colors {
            let lab = ColorScience.lab(fromSRGB: (c.x, c.y, c.z))
            ls.append(lab.l); sumA += lab.a; sumB += lab.b; sumC += hypot(lab.a, lab.b)
        }
        let n = Double(max(colors.count, 1))
        let mean = ls.reduce(0, +) / n
        meanL = mean
        stdL = sqrt(ls.reduce(0) { $0 + pow($1 - mean, 2) } / n)
        ls.sort()
        lowL = ls.isEmpty ? 0 : ls[Int(Double(ls.count - 1) * 0.05)]
        highL = ls.isEmpty ? 0 : ls[Int(Double(ls.count - 1) * 0.95)]
        meanA = sumA / n; meanB = sumB / n; meanChroma = sumC / n
    }

    /// Weighted squared distance, roughly in "just noticeable" units.
    func distance(to t: ColorStats) -> Double {
        let dl = (meanL - t.meanL) / 3, ds = (stdL - t.stdL) / 3
        let dlo = (lowL - t.lowL) / 4, dhi = (highL - t.highL) / 4
        let da = (meanA - t.meanA) / 2, db = (meanB - t.meanB) / 2, dc = (meanChroma - t.meanChroma) / 3
        return dl * dl + ds * ds + dlo * dlo + dhi * dhi + da * da + db * db + dc * dc
    }
}

/// What the app keeps about an example photo (spec 05): its statistics, never the photo itself.
public struct ReferenceProfile: Codable, Sendable, Hashable {
    public static let currentVersion = 1
    public var version: Int
    public var stats: ColorStats
    public var cornerRatio: Double

    public init(sample: SceneSample) {
        version = Self.currentVersion
        stats = ColorStats(colors: sample.colors)
        cornerRatio = sample.cornerRatio
    }

    /// Black-and-white example (spec 05 uç durum).
    public var isMonochrome: Bool { stats.meanChroma < 2.5 }
}

/// Finds the color adjustments that make *this scene* look like the example (spec 05 FR-010).
/// Pure and deterministic: same scene sample and profile, same result.
public enum LookMatcher {
    public struct Result: Sendable, Hashable {
        /// Applied by `LookRenderer` in the preview and the saved photo.
        public var adjustments: LookAdjustments
        /// Brightness difference the camera should take over, in stops (spec 02 FR-004).
        public var exposureStops: Double
    }

    /// Small looks are preferred: each unit of adjustment costs this much in the objective.
    static let regularization = 0.6
    /// Corner darkening produced by `vignette = 1` (measured on the renderer, see tests).
    static let vignetteRatioDrop = 0.42

    public static func match(scene: SceneSample, to profile: ReferenceProfile) -> Result {
        let target = profile.stats
        // Fewer colors for the search keeps it fast; the stats are stable at this size.
        let colors = stride(from: 0, to: scene.colors.count, by: max(1, scene.colors.count / 600)).map { scene.colors[$0] }

        var params = [Double](repeating: 0, count: Param.allCases.count)
        if profile.isMonochrome { params[Param.saturation.rawValue] = -1 }
        func cost(_ p: [Double]) -> Double {
            let stats = ColorStats(colors: transformed(colors, Param.adjustments(p)))
            return stats.distance(to: target) + regularization * p.reduce(0) { $0 + $1 * $1 }
        }

        var best = cost(params)
        var step = 0.25
        while step > 0.01 {
            var improved = false
            for param in Param.allCases {
                if profile.isMonochrome && param == .saturation { continue }
                for direction in [1.0, -1.0] {
                    var candidate = params
                    candidate[param.rawValue] = min(param.range.upperBound, max(param.range.lowerBound, candidate[param.rawValue] + direction * step))
                    let c = cost(candidate)
                    if c < best - 1e-9 { best = c; params = candidate; improved = true; break }
                }
            }
            if !improved { step /= 2 }
        }

        var adjustments = Param.adjustments(params)
        let drop = scene.cornerRatio - profile.cornerRatio
        adjustments.vignette = min(1, max(0, drop / vignetteRatioDrop))
        return Result(adjustments: adjustments, exposureStops: adjustments.exposure)
    }

    static func transformed(_ colors: [SIMD3<Double>], _ a: LookAdjustments) -> [SIMD3<Double>] {
        let t = ColorTransform(a)
        return colors.map { let (r, g, b) = t.apply($0.x, $0.y, $0.z); return SIMD3(r, g, b) }
    }

    enum Param: Int, CaseIterable {
        case exposure, contrast, shadows, highlights, fade, temperature, tint, saturation

        var range: ClosedRange<Double> { self == .fade ? 0...1 : -1...1 }

        static func adjustments(_ p: [Double]) -> LookAdjustments {
            var a = LookAdjustments()
            a.exposure = p[Param.exposure.rawValue]; a.contrast = p[Param.contrast.rawValue]
            a.shadows = p[Param.shadows.rawValue]; a.highlights = p[Param.highlights.rawValue]
            a.fade = p[Param.fade.rawValue]; a.temperature = p[Param.temperature.rawValue]
            a.tint = p[Param.tint.rawValue]; a.saturation = p[Param.saturation.rawValue]
            return a
        }
    }
}

