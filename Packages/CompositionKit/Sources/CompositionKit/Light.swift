import CoreGraphics
import FrameKit
import Foundation

/// Brightness on a small grid (0–1, row-major, origin top-left).
public struct LuminanceGrid: Sendable, Hashable {
    public var width: Int
    public var height: Int
    public var values: [Double]
    public init(width: Int, height: Int, values: [Double]) { self.width = width; self.height = height; self.values = values }

    func mean(in rect: CGRect) -> Double? {
        let x0 = max(0, Int((rect.minX * CGFloat(width)).rounded(.down))), x1 = min(width, Int((rect.maxX * CGFloat(width)).rounded(.up)))
        let y0 = max(0, Int((rect.minY * CGFloat(height)).rounded(.down))), y1 = min(height, Int((rect.maxY * CGFloat(height)).rounded(.up)))
        guard x1 > x0, y1 > y0 else { return nil }
        var sum = 0.0
        for y in y0..<y1 { for x in x0..<x1 { sum += values[y * width + x] } }
        return sum / Double((x1 - x0) * (y1 - y0))
    }
}

/// How the subject is lit (spec 04 FR-L1).
public struct LightReading: Codable, Sendable, Hashable {
    /// Subject brightness / surrounding brightness. Well below 1 = backlit.
    public var subjectToBackground: Double
    /// (right half − left half) / (right + left) of the subject, as seen in the image. Negative = lit from the left.
    public var sideBalance: Double

    public init(subjectToBackground: Double, sideBalance: Double) {
        self.subjectToBackground = subjectToBackground; self.sideBalance = sideBalance
    }
}

public enum LightAnalyzer {
    public static func read(_ grid: LuminanceGrid, subject box: CGRect) -> LightReading? {
        let b = box.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !b.isNull, b.width > 0.05, b.height > 0.05, let inside = grid.mean(in: b) else { return nil }
        // Surroundings: a band around the subject.
        let ring = b.insetBy(dx: -b.width * 0.35, dy: -b.height * 0.2).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let around = grid.mean(in: ring) else { return nil }
        let ringArea = ring.width * ring.height, boxArea = b.width * b.height
        let background = ringArea > boxArea * 1.05 ? (around * Double(ringArea) - inside * Double(boxArea)) / Double(ringArea - boxArea) : around
        let left = grid.mean(in: CGRect(x: b.minX, y: b.minY, width: b.width / 2, height: b.height)) ?? inside
        let right = grid.mean(in: CGRect(x: b.midX, y: b.minY, width: b.width / 2, height: b.height)) ?? inside
        return LightReading(subjectToBackground: inside / max(background, 0.02),
                            sideBalance: (right - left) / max(right + left, 0.02))
    }
}

extension CompositionGuide {
    public struct LightContext: Sendable {
        public var live: LightReading?
        public var example: LightReading?
        /// From the camera's own exposure (spec 04 FR-L2).
        public var isDim: Bool
        public init(live: LightReading?, example: LightReading?, isDim: Bool) { self.live = live; self.example = example; self.isDim = isDim }
    }

    static let backlitRatio = 0.55
    static let sideLight = 0.12

    /// Location problems (backlit, dim): fixed before framing because moving resets the framing.
    static func lightProblem(_ light: LightContext?) -> GuidanceInstruction? {
        guard let light else { return nil }
        if let live = light.live, live.subjectToBackground < backlitRatio,
           (light.example?.subjectToBackground ?? 1) >= 0.75 {
            return GuidanceInstruction(kind: "light.backlit", priority: 1, phraseKey: "guide.light.backlit")
        }
        if light.isDim { return GuidanceInstruction(kind: "light.dim", priority: 1, phraseKey: "guide.light.dim") }
        return nil
    }

    /// Fine tuning after pose: light coming from the same side as in the example.
    static func lightDirection(_ light: LightContext?) -> GuidanceInstruction? {
        guard let e = light?.example, let l = light?.live, abs(e.sideBalance) > sideLight else { return nil }
        let wantLeft = e.sideBalance < 0
        let liveMatches = wantLeft ? l.sideBalance < -sideLight / 2 : l.sideBalance > sideLight / 2
        guard !liveMatches else { return nil }
        return wantLeft
            ? GuidanceInstruction(kind: "light.fromLeft", direction: .left, priority: 4, phraseKey: "guide.light.fromLeft")
            : GuidanceInstruction(kind: "light.fromRight", direction: .right, priority: 4, phraseKey: "guide.light.fromRight")
    }
}
