import CoreGraphics
import FrameKit
import Foundation

/// Brightness on a small grid (0–1, row-major, origin top-left).
public struct LuminanceGrid: Sendable, Hashable {
    public var width: Int
    public var height: Int
    public var values: [Double]
    public init(width: Int, height: Int, values: [Double]) { self.width = width; self.height = height; self.values = values }

    /// Draws the image (upright, as given) into a small gray grid. Used for the example's finer light reading.
    public init?(image: CGImage, width: Int = 96, height: Int = 120) {
        var px = [UInt8](repeating: 0, count: width * height)
        guard let ctx = CGContext(data: &px, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Row 0 of the bitmap is the top of the image.
        self.init(width: width, height: height, values: px.map { Double($0) / 255 })
    }

    func patch(in rect: CGRect) -> (values: [Double], w: Int, h: Int)? {
        let x0 = max(0, Int((rect.minX * CGFloat(width)).rounded(.down))), x1 = min(width, Int((rect.maxX * CGFloat(width)).rounded(.up)))
        let y0 = max(0, Int((rect.minY * CGFloat(height)).rounded(.down))), y1 = min(height, Int((rect.maxY * CGFloat(height)).rounded(.up)))
        guard x1 - x0 >= 3, y1 - y0 >= 3 else { return nil }
        var out: [Double] = []
        out.reserveCapacity((x1 - x0) * (y1 - y0))
        for y in y0..<y1 { for x in x0..<x1 { out.append(values[y * width + x]) } }
        return (out, x1 - x0, y1 - y0)
    }

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

    /// (top half − bottom half) / (top + bottom) of the subject. Positive = lit from above (spec 05 FR-013).
    public var verticalBalance: Double?
    /// Brightest vs darkest part of the subject, in stops (90th / 10th percentile of linear light). Example only.
    public var shadowDepth: Double?
    /// How abruptly light turns into shadow: steepest steps relative to the subject's range. Example only.
    public var edgeSharpness: Double?

    public init(subjectToBackground: Double, sideBalance: Double, verticalBalance: Double? = nil,
                shadowDepth: Double? = nil, edgeSharpness: Double? = nil) {
        self.subjectToBackground = subjectToBackground; self.sideBalance = sideBalance
        self.verticalBalance = verticalBalance; self.shadowDepth = shadowDepth; self.edgeSharpness = edgeSharpness
    }
}

/// Where the light comes from, as seen by the photographer, and what it is like (spec 05 FR-013).
public enum LightSource: String, Codable, Sendable, Hashable, CaseIterable { case left, right, front, back, top }
public enum LightQuality: String, Codable, Sendable, Hashable, CaseIterable { case soft, hard }

public enum LightCharacter {
    // Same side threshold as the live advice (spec 04 FR-L3) so the card and the camera agree.
    static let side = CompositionGuide.sideLight
    static let vertical = 0.15
    static let backlit = CompositionGuide.backlitRatio

    /// `angle` matters for top-down shots: the top of the frame is the far side of the table, so light from
    /// there comes from behind the subject, and light from the bottom comes from the photographer's side.
    public static func source(_ r: LightReading, angle: ShotAngle? = nil) -> LightSource? {
        let v = r.verticalBalance ?? 0
        if r.subjectToBackground < backlit, angle != .topDown { return .back }
        if abs(r.sideBalance) > side, abs(r.sideBalance) >= abs(v) { return r.sideBalance < 0 ? .left : .right }
        if v > vertical { return angle == .topDown ? .back : .top }
        if v < -vertical { return angle == .topDown ? .front : nil }
        if abs(r.sideBalance) < side / 2, abs(v) < vertical / 2, r.subjectToBackground >= 0.9,
           let depth = r.shadowDepth, depth < 1.5 { return .front }
        return nil
    }

    static let hardSharpness = 0.2
    static let softSharpness = 0.1
    static let hardDepth = 1.6
    static let softDepth = 1.2

    public static func quality(_ r: LightReading) -> LightQuality? {
        guard let sharp = r.edgeSharpness, let depth = r.shadowDepth else { return nil }
        if sharp >= hardSharpness, depth >= hardDepth { return .hard }
        if sharp <= softSharpness || depth <= softDepth { return .soft }
        return nil
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
        let top = grid.mean(in: CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height / 2)) ?? inside
        let bottom = grid.mean(in: CGRect(x: b.minX, y: b.midY, width: b.width, height: b.height / 2)) ?? inside
        return LightReading(subjectToBackground: inside / max(background, 0.02),
                            sideBalance: (right - left) / max(right + left, 0.02),
                            verticalBalance: (top - bottom) / max(top + bottom, 0.02))
    }

    /// The example's reading, with shadow depth and edge sharpness from a finer grid (spec 05 FR-013).
    /// Without a subject, the middle of the frame stands in for it.
    public static func readExample(_ fine: LuminanceGrid, subject box: CGRect?) -> LightReading? {
        let region = box ?? CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        // Depth and sharpness from the inside of the subject: its outline against the background is always a
        // sharp edge, whatever the light.
        let inner = region.insetBy(dx: region.width * 0.15, dy: region.height * 0.15)
        guard var reading = read(fine, subject: region), let (v, w, h) = fine.patch(in: inner) else { return nil }
        let linear = v.map(Self.linear).sorted()
        let p10 = linear[Int(Double(linear.count - 1) * 0.1)], p90 = linear[Int(Double(linear.count - 1) * 0.9)]
        reading.shadowDepth = log2(max(p90, 0.002) / max(p10, 0.002))
        // Steepest steps (98th percentile gradient) per pixel, relative to the range of the subject.
        let sorted = v.sorted()
        let range = sorted[Int(Double(sorted.count - 1) * 0.95)] - sorted[Int(Double(sorted.count - 1) * 0.05)]
        var grads: [Double] = []
        grads.reserveCapacity(w * h)
        for y in 1..<(h - 1) { for x in 1..<(w - 1) {
            let gx = (v[y * w + x + 1] - v[y * w + x - 1]) / 2, gy = (v[(y + 1) * w + x] - v[(y - 1) * w + x]) / 2
            grads.append(hypot(gx, gy))
        } }
        grads.sort()
        let steep = grads.isEmpty ? 0 : grads[Int(Double(grads.count - 1) * 0.98)]
        reading.edgeSharpness = range > 0.05 ? steep / range : 0
        return reading
    }

    static func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
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
