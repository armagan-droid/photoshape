import CoreGraphics
import Foundation

/// Smart exposure (spec 02 FR-002, FR-009): measure on the subject, protect its bright parts, then aim for a
/// readable subject (plus the example's brightness preference). Pure; the camera applies the result as an
/// exposure target bias and a metering point.
public enum ExposureDecider {
    public enum Reason: String, Sendable, Hashable {
        case none
        case subjectBrightened
        case subjectDarkened
        case highlightsProtected
    }

    public struct Decision: Sendable, Hashable {
        /// New exposure target bias in stops.
        public var bias: Double
        /// Where the camera should meter (normalized, top-left), nil = whole frame.
        public var meteringPoint: CGPoint?
        public var reason: Reason
    }

    /// Mid-gray-ish target for a subject, gamma encoded.
    static let target = 0.47
    /// The brightest part of the subject may reach this, not more.
    static let highlightLimit = 0.92
    static let gain = 0.6
    static let deadband = 0.15
    public static let biasRange: ClosedRange<Double> = -2...1.5

    /// - Parameters:
    ///   - grid: brightness of the current frame (already exposed with `currentBias`).
    ///   - subject: subject box in the frame, nil = center of the frame.
    ///   - exampleOffset: brightness preference from the example, in stops (spec 05 FR-009).
    public static func decide(grid: LuminanceGrid, subject: CGRect?, currentBias: Double, exampleOffset: Double = 0) -> Decision {
        let region = (subject ?? CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        let values = grid.values(in: region)
        guard !values.isEmpty else { return Decision(bias: currentBias, meteringPoint: nil, reason: .none) }
        let mean = values.reduce(0, +) / Double(values.count)
        let bright = percentile(values, 0.97)

        let targetLin = linear(target) * pow(2, max(-1, min(1, exampleOffset)))
        var delta = log2(targetLin / max(linear(mean), 0.002))
        let headroom = log2(linear(highlightLimit) / max(linear(bright), 0.002))
        // Never brighter than the subject's bright parts allow (may even darken if they are already too bright).
        let limited = delta - headroom > 0.25
        delta = min(delta, headroom)

        let point = CGPoint(x: region.midX, y: region.midY)
        guard abs(delta) >= deadband else {
            return Decision(bias: currentBias, meteringPoint: point, reason: limited ? .highlightsProtected : reason(for: currentBias))
        }
        let bias = min(biasRange.upperBound, max(biasRange.lowerBound, currentBias + gain * delta))
        return Decision(bias: bias, meteringPoint: point, reason: limited ? .highlightsProtected : reason(for: bias))
    }

    static func reason(for bias: Double) -> Reason {
        bias >= 0.5 ? .subjectBrightened : bias <= -0.5 ? .subjectDarkened : .none
    }

    static func percentile(_ v: [Double], _ p: Double) -> Double {
        let s = v.sorted()
        return s[min(s.count - 1, Int(Double(s.count - 1) * p))]
    }

    static func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
}

extension LuminanceGrid {
    func values(in rect: CGRect) -> [Double] {
        let x0 = max(0, Int((rect.minX * CGFloat(width)).rounded(.down))), x1 = min(width, Int((rect.maxX * CGFloat(width)).rounded(.up)))
        let y0 = max(0, Int((rect.minY * CGFloat(height)).rounded(.down))), y1 = min(height, Int((rect.maxY * CGFloat(height)).rounded(.up)))
        guard x1 > x0, y1 > y0 else { return [] }
        var out: [Double] = []
        out.reserveCapacity((x1 - x0) * (y1 - y0))
        for y in y0..<y1 { for x in x0..<x1 { out.append(values[y * width + x]) } }
        return out
    }
}
