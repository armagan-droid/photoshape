import CoreGraphics
import Foundation
import Vision

/// Where the camera looks from (spec 05 FR-012).
public enum ShotAngle: String, Codable, Sendable, Hashable, CaseIterable {
    case topDown, angled, eyeLevel
}

public struct ShotAngleEstimate: Codable, Sendable, Hashable {
    public var angle: ShotAngle
    /// 0–1. The card shows the angle only above `ShotAngleEstimator.minimumConfidence`.
    public var confidence: Double
    public init(angle: ShotAngle, confidence: Double) { self.angle = angle; self.confidence = confidence }
}

/// An ellipse fitted to a closed outline, in pixel-proportional units (x and y on the same scale).
public struct Ellipse: Sendable, Hashable {
    public var center: CGPoint
    public var major: Double
    public var minor: Double
    /// Angle of the major axis from horizontal, radians in −π/2…π/2.
    public var orientation: Double
    /// Mean |normalized radius − 1| over the outline points: about 0 for a true ellipse, ≈ 0.1 for a square.
    public var fitError: Double
    /// Enclosed area as a fraction of the image.
    public var areaFraction: Double

    /// Short axis / long axis: 1 seen from straight above, flatter as the view tilts toward the horizon.
    public var ratio: Double { major > 0 ? minor / major : 0 }
}

/// Estimates the shot angle from round things (cups, plates, bowls). A circle seen at an angle becomes an
/// ellipse whose short/long ratio is the cosine of the tilt from straight down. Vision's horizon request only
/// reports roll, not tilt, so it is not used. When nothing round is found the angle is unknown (Hikâye 7.3).
public enum ShotAngleEstimator {
    public static let minimumConfidence = 0.5
    static let maxFitError = 0.06
    static let minArea = 0.008
    /// Foreshortening squashes circles vertically, so a tilted circle's long axis is near horizontal.
    static let maxTiltedOrientation = 25.0 * .pi / 180

    // Ratio bands: cos(35°) ≈ 0.82, cos(75°) ≈ 0.26.
    static let topDownMin = 0.82
    static let angledRange = 0.30...0.76
    static let eyeLevelMax = 0.24

    /// Second moments of the polygon's enclosed area (Green's theorem) give the axes; the outline points give the fit.
    public static func fitEllipse(_ points: [CGPoint], imageArea: Double = 1) -> Ellipse? {
        guard points.count >= 8 else { return nil }
        var a = 0.0, cx = 0.0, cy = 0.0
        let n = points.count
        for i in 0..<n {
            let p = points[i], q = points[(i + 1) % n]
            let cross = Double(p.x * q.y - q.x * p.y)
            a += cross
            cx += Double(p.x + q.x) * cross
            cy += Double(p.y + q.y) * cross
        }
        a /= 2
        guard abs(a) > 1e-9 else { return nil }
        cx /= 6 * a; cy /= 6 * a
        // Central second moments of the area.
        var sxx = 0.0, syy = 0.0, sxy = 0.0
        for i in 0..<n {
            let p = CGPoint(x: points[i].x - cx, y: points[i].y - cy)
            let q = CGPoint(x: points[(i + 1) % n].x - cx, y: points[(i + 1) % n].y - cy)
            let cross = Double(p.x * q.y - q.x * p.y)
            sxx += cross * Double(p.y * p.y + p.y * q.y + q.y * q.y)
            syy += cross * Double(p.x * p.x + p.x * q.x + q.x * q.x)
            sxy += cross * Double(p.x * q.y + 2 * p.x * p.y + 2 * q.x * q.y + q.x * p.y)
        }
        // Integrals of y², x², xy over the region, divided by the area → covariance.
        let area = abs(a)
        let cyy = abs(sxx / 12) / area, cxx = abs(syy / 12) / area
        let cxy = (sxy / 24) / a
        let tr = cxx + cyy, det = cxx * cyy - cxy * cxy
        let disc = max(0, tr * tr / 4 - det)
        let l1 = tr / 2 + sqrt(disc), l2 = max(0, tr / 2 - sqrt(disc))
        guard l1 > 0 else { return nil }
        let major = 2 * sqrt(l1), minor = 2 * sqrt(l2)
        let theta = 0.5 * atan2(2 * cxy, cxx - cyy)
        // Fit: normalized radius of every outline point in the ellipse's own frame.
        let c = cos(theta), s = sin(theta)
        var err = 0.0
        for p in points {
            let dx = Double(p.x) - cx, dy = Double(p.y) - cy
            let u = dx * c + dy * s, v = -dx * s + dy * c
            err += abs(sqrt((u / major) * (u / major) + (v / max(minor, 1e-9)) * (v / max(minor, 1e-9))) - 1)
        }
        return Ellipse(center: CGPoint(x: cx, y: cy), major: major, minor: minor, orientation: theta,
                       fitError: err / Double(n), areaFraction: area / imageArea)
    }

    /// Pure decision from the ellipses found in an image (tested with synthetic outlines).
    public static func classify(_ ellipses: [Ellipse]) -> ShotAngleEstimate? {
        let usable = ellipses.filter { e in
            e.fitError <= maxFitError && e.areaFraction >= minArea && e.areaFraction <= 0.9 &&
                (e.ratio >= topDownMin || abs(e.orientation) <= maxTiltedOrientation)
        }
        .sorted { $0.areaFraction > $1.areaFraction }
        .prefix(4)
        guard !usable.isEmpty else { return nil }
        // Area-weighted mean ratio of the biggest round things.
        let weight = usable.reduce(0) { $0 + $1.areaFraction }
        let ratio = usable.reduce(0) { $0 + $1.ratio * $1.areaFraction } / weight
        let spread = usable.map { abs($0.ratio - ratio) }.max() ?? 0
        let angle: ShotAngle
        let margin: Double
        if ratio >= topDownMin { angle = .topDown; margin = (ratio - topDownMin) / 0.08 + 0.5 }
        else if angledRange.contains(ratio) {
            angle = .angled; margin = min(ratio - angledRange.lowerBound, angledRange.upperBound - ratio) / 0.06 + 0.5
        } else if ratio <= eyeLevelMax { angle = .eyeLevel; margin = (eyeLevelMax - ratio) / 0.06 + 0.5 }
        else { return nil } // between bands: not sure
        // Disagreeing ellipses lower the confidence.
        let confidence = min(1, margin) * max(0, 1 - spread * 3)
        return ShotAngleEstimate(angle: angle, confidence: confidence)
    }

    /// Finds round outlines with Vision and classifies them. Returns nil when unsure.
    public static func estimate(in image: CGImage) -> ShotAngleEstimate? {
        let w = Double(image.width), h = Double(image.height)
        guard w > 0, h > 0 else { return nil }
        var ellipses: [Ellipse] = []
        for darkOnLight in [true, false] {
            let request = VNDetectContoursRequest()
            request.maximumImageDimension = 512
            request.contrastAdjustment = 1.5
            request.detectsDarkOnLight = darkOnLight
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            guard (try? handler.perform([request])) != nil, let observation = request.results?.first else { continue }
            for i in 0..<observation.contourCount {
                guard let contour = try? observation.contour(at: i), contour.pointCount >= 24 else { continue }
                // Normalized points → pixel-proportional so that circles stay circles.
                let pts = contour.normalizedPoints.map { CGPoint(x: Double($0.x) * w / h, y: Double($0.y)) }
                if let e = fitEllipse(pts, imageArea: w / h) { ellipses.append(e) }
            }
        }
        guard let estimate = classify(ellipses), estimate.confidence >= minimumConfidence else { return nil }
        return estimate
    }
}
