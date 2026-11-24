import CoreGraphics
import Foundation
import Testing
@testable import CompositionKit

/// Synthetic images for the shot angle (spec 05 SC-007, synthetic part: must be 100% right).
enum Drawn {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    static func context(width: Int, height: Int, gray: Double) -> CGContext {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(gray: gray, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx
    }

    /// A table with plates (circles seen at a tilt: height = width × ratio) and a cup.
    static func table(ratio: Double, width: Int = 800, height: Int = 1000) -> CGImage {
        let ctx = context(width: width, height: height, gray: 0.3)
        let w = Double(width)
        ctx.setFillColor(CGColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: w * 0.2, y: Double(height) * 0.45, width: w * 0.6, height: w * 0.6 * ratio))
        ctx.setFillColor(CGColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: w * 0.32, y: Double(height) * 0.45 + w * 0.6 * ratio * 0.2,
                                   width: w * 0.36, height: w * 0.36 * ratio))
        ctx.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.88, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: w * 0.1, y: Double(height) * 0.12, width: w * 0.3, height: w * 0.3 * ratio))
        return ctx.makeImage()!
    }

    /// No round things: rectangles only.
    static func boxes() -> CGImage {
        let ctx = context(width: 800, height: 1000, gray: 0.35)
        ctx.setFillColor(CGColor(gray: 0.9, alpha: 1))
        ctx.fill(CGRect(x: 120, y: 200, width: 400, height: 300))
        ctx.fill(CGRect(x: 500, y: 650, width: 200, height: 250))
        return ctx.makeImage()!
    }
}

@Suite("Shot angle from round things (spec 05 FR-012, SC-007)")
struct AngleTests {
    static func outline(rx: Double, ry: Double, rotation: Double = 0, n: Int = 120) -> [CGPoint] {
        (0..<n).map { i in
            let t = Double(i) / Double(n) * 2 * .pi
            let x = rx * cos(t), y = ry * sin(t)
            return CGPoint(x: 0.5 + x * cos(rotation) - y * sin(rotation), y: 0.5 + x * sin(rotation) + y * cos(rotation))
        }
    }

    @Test func fitsEllipseAxesAndRejectsSquares() throws {
        let e = try #require(ShotAngleEstimator.fitEllipse(Self.outline(rx: 0.3, ry: 0.15)))
        #expect(abs(e.major - 0.3) < 0.005 && abs(e.minor - 0.15) < 0.005)
        #expect(abs(e.ratio - 0.5) < 0.02)
        #expect(e.fitError < 0.01)
        #expect(abs(e.orientation) < 0.02)
        let square = [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.2), CGPoint(x: 0.8, y: 0.8), CGPoint(x: 0.2, y: 0.8)]
            .flatMap { p in (0..<10).map { _ in p } } // repeated corners are still a square outline
        let sq = ShotAngleEstimator.fitEllipse(Self.densify(square))
        #expect((sq?.fitError ?? 1) > ShotAngleEstimator.maxFitError)
    }

    static func densify(_ corners: [CGPoint]) -> [CGPoint] {
        let unique = corners.enumerated().filter { $0.offset % 10 == 0 }.map(\.element)
        var out: [CGPoint] = []
        for i in unique.indices {
            let a = unique[i], b = unique[(i + 1) % unique.count]
            for k in 0..<30 { let t = CGFloat(k) / 30; out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)) }
        }
        return out
    }

    @Test(arguments: [(1.0, ShotAngle.topDown), (0.9, .topDown), (0.6, .angled), (0.4, .angled), (0.15, .eyeLevel)])
    func classifiesByRatio(ratio: Double, expected: ShotAngle) throws {
        let e = try #require(ShotAngleEstimator.fitEllipse(Self.outline(rx: 0.3, ry: 0.3 * ratio)))
        #expect(ShotAngleEstimator.classify([e])?.angle == expected)
    }

    @Test func unsureBetweenBandsAndForVerticalEllipses() throws {
        let between = try #require(ShotAngleEstimator.fitEllipse(Self.outline(rx: 0.3, ry: 0.3 * 0.79)))
        #expect(ShotAngleEstimator.classify([between]) == nil)
        // A tall ellipse is not a tilted circle (foreshortening squashes vertically).
        let tall = try #require(ShotAngleEstimator.fitEllipse(Self.outline(rx: 0.3, ry: 0.15, rotation: .pi / 2)))
        #expect(ShotAngleEstimator.classify([tall]) == nil)
        #expect(ShotAngleEstimator.classify([]) == nil)
    }

    @Test(arguments: [(1.0, ShotAngle.topDown), (0.55, .angled), (0.4, .angled)])
    func readsDrawnTables(ratio: Double, expected: ShotAngle) throws {
        let estimate = try #require(ShotAngleEstimator.estimate(in: Drawn.table(ratio: ratio)))
        #expect(estimate.angle == expected, "ratio \(ratio): \(estimate)")
    }

    @Test func nothingRoundMeansUnknown() {
        #expect(ShotAngleEstimator.estimate(in: Drawn.boxes()) == nil)
    }
}

extension Drawn {
    /// A subject box lit in a known way on a plain background. `shade(fx, fy)` gives the subject's gray level
    /// at normalized position inside the box (origin top-left).
    static func lit(background: Double, box: CGRect = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
                    width: Int = 400, height: Int = 500, shade: (Double, Double) -> Double) -> CGImage {
        var px = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height { for x in 0..<width {
            let fx = (Double(x) + 0.5) / Double(width), fy = (Double(y) + 0.5) / Double(height)
            var g = background
            if box.contains(CGPoint(x: fx, y: fy)) {
                g = shade((fx - box.minX) / box.width, (fy - box.minY) / box.height)
            }
            px[y * width + x] = UInt8(max(0, min(255, (g * 255).rounded())))
        } }
        let ctx = CGContext(data: &px, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        return ctx.makeImage()!
    }
}

@Suite("Light direction and character of the example (spec 05 FR-013, SC-008, SC-009)")
struct LightCharacterTests {
    static let box = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)

    static func reading(_ image: CGImage) throws -> LightReading {
        let grid = try #require(LuminanceGrid(image: image))
        return try #require(LightAnalyzer.readExample(grid, subject: box))
    }

    static let cases: [(String, CGImage, LightSource?, LightQuality?)] = [
        ("soft left", Drawn.lit(background: 0.45) { fx, _ in 0.85 - 0.45 * fx }, .left, .soft),
        ("hard left", Drawn.lit(background: 0.45) { fx, _ in fx < 0.5 ? 0.85 : 0.18 }, .left, .hard),
        ("soft right", Drawn.lit(background: 0.45) { fx, _ in 0.4 + 0.45 * fx }, .right, .soft),
        ("hard right", Drawn.lit(background: 0.45) { fx, _ in fx > 0.55 ? 0.85 : 0.15 }, .right, .hard),
        ("top", Drawn.lit(background: 0.45) { _, fy in 0.85 - 0.45 * fy }, .top, .soft),
        ("back", Drawn.lit(background: 0.95) { _, _ in 0.3 }, .back, .soft),
        ("front", Drawn.lit(background: 0.5) { _, _ in 0.72 }, .front, .soft),
    ]

    @Test func readsEveryDrawnLight() throws {
        for (name, image, source, quality) in Self.cases {
            let r = try Self.reading(image)
            #expect(LightCharacter.source(r) == source, "\(name): \(r)")
            #expect(LightCharacter.quality(r) == quality, "\(name): \(r)")
        }
    }

    @Test func topDownShotsTurnFrameTopIntoBehind() {
        let fromFarSide = LightReading(subjectToBackground: 1, sideBalance: 0, verticalBalance: 0.3)
        #expect(LightCharacter.source(fromFarSide) == .top)
        #expect(LightCharacter.source(fromFarSide, angle: .topDown) == .back)
        let fromNearSide = LightReading(subjectToBackground: 1, sideBalance: 0, verticalBalance: -0.3)
        #expect(LightCharacter.source(fromNearSide) == nil)
        #expect(LightCharacter.source(fromNearSide, angle: .topDown) == .front)
    }

    @Test func oldReadingsWithoutDetailsHaveNoQuality() {
        #expect(LightCharacter.quality(LightReading(subjectToBackground: 1, sideBalance: -0.3)) == nil)
        #expect(LightCharacter.source(LightReading(subjectToBackground: 1, sideBalance: -0.3)) == .left)
    }

    /// Old saved examples (before 2026-11-23) decode with the new fields empty.
    @Test func decodesOldReadings() throws {
        let old = #"{"subjectToBackground":0.8,"sideBalance":-0.2}"#.data(using: .utf8)!
        let r = try JSONDecoder().decode(LightReading.self, from: old)
        #expect(r.verticalBalance == nil && r.shadowDepth == nil && r.edgeSharpness == nil)
    }
}
