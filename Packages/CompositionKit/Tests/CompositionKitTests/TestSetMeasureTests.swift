#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import LookKit
import Testing
import TestSetKit
@testable import CompositionKit

/// SC-007..SC-010 on the labeled test set (spec 00). While the set has too few labeled frames the numbers are
/// printed but not enforced; the branch is not merged before they are (Constitution, Geliştirme Akışı 4).
@Suite("Example card on the test set (spec 05 SC-007…SC-010)")
struct TestSetMeasureTests {
    /// Below this many labeled frames a criterion is reported, not enforced.
    static let minimumFrames = 10

    struct Score: CustomStringConvertible {
        var labeled = 0, shown = 0, correct = 0
        var precision: Double { shown > 0 ? Double(correct) / Double(shown) : 0 }
        var coverage: Double { labeled > 0 ? Double(shown) / Double(labeled) : 0 }
        var description: String { "\(labeled) labeled, shown \(shown), correct \(correct)" }
    }

    static func set() -> TestSet? { try? TestSet.locate() }

    static func subjectBox(_ f: TestFrame) -> CGRect? {
        f.labels.subjectRegion.map { CGRect(x: $0.x, y: $0.y, width: $0.w, height: $0.h) }
    }

    static func report(_ name: String, _ s: Score, precision: Double, coverage: Double?) {
        print("[\(name)] \(s) → precision \(String(format: "%.2f", s.precision)), coverage \(String(format: "%.2f", s.coverage))")
        guard s.labeled >= minimumFrames else {
            print("[\(name)] not measured yet: needs \(minimumFrames) labeled frames"); return
        }
        #expect(s.precision >= precision, "\(name) precision")
        if let coverage { #expect(s.coverage >= coverage, "\(name) coverage") }
    }

    @Test func sc007Angle() throws {
        guard let set = Self.set() else { print("[SC-007] no test set"); return }
        var s = Score()
        for f in set.frames(where: { $0.labels.cameraAngle != nil }) {
            s.labeled += 1
            guard let estimate = ShotAngleEstimator.estimate(in: try f.loadImage()) else { continue }
            s.shown += 1
            let expected: ShotAngle = switch f.labels.cameraAngle! {
            case .topDown: .topDown
            case .angled: .angled
            case .eyeLevel: .eyeLevel
            }
            if estimate.angle == expected { s.correct += 1 }
        }
        Self.report("SC-007 angle", s, precision: 0.85, coverage: 0.70)
    }

    @Test func sc008and009Light() throws {
        guard let set = Self.set() else { print("[SC-008] no test set"); return }
        var direction = Score(), quality = Score()
        for f in set.frames(where: { $0.labels.lightDirection != nil || $0.labels.lightQuality != nil }) {
            guard let grid = LuminanceGrid(image: try f.loadImage()),
                  let reading = LightAnalyzer.readExample(grid, subject: Self.subjectBox(f)) else { continue }
            let angle: ShotAngle? = switch f.labels.cameraAngle {
            case .topDown?: .topDown
            case .angled?: .angled
            case .eyeLevel?: .eyeLevel
            case nil: nil
            }
            if let label = f.labels.lightDirection {
                direction.labeled += 1
                if let source = LightCharacter.source(reading, angle: angle) {
                    direction.shown += 1
                    if source.rawValue == label.rawValue { direction.correct += 1 }
                } else if label == .diffuse {
                    direction.correct += 1; direction.shown += 1 // leaving the line out is right for diffuse light
                }
            }
            if let label = f.labels.lightQuality {
                quality.labeled += 1
                if let q = LightCharacter.quality(reading) {
                    quality.shown += 1
                    if q.rawValue == label.rawValue { quality.correct += 1 }
                }
            }
        }
        Self.report("SC-008 light direction", direction, precision: 0.80, coverage: 0.60)
        Self.report("SC-009 light quality", quality, precision: 0.80, coverage: nil)
    }

    @Test func sc010WarmCast() throws {
        guard let set = Self.set() else { print("[SC-010] no test set"); return }
        var s = Score()
        for f in set.frames(where: { $0.labels.whiteBalance == .warmCast }) {
            s.labeled += 1
            guard let sample = SceneSample(image: try f.loadImage()) else { continue }
            s.shown += 1
            if ExampleReading.color(ColorStats(colors: sample.colors)).hasPrefix("warm") { s.correct += 1 }
        }
        Self.report("SC-010 warm cast", s, precision: 0.80, coverage: nil)
    }

    /// SC-014 (set part): iPhone frames carry shutter, aperture and ISO.
    @Test func sc014CameraData() throws {
        guard let set = Self.set() else { print("[SC-014] no test set"); return }
        var s = Score()
        for f in set.frames {
            s.labeled += 1
            guard let source = CGImageSourceCreateWithURL(f.imageURL as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
                  let settings = ExampleSettings(properties: props) else { continue }
            s.shown += 1
            if settings.exposureTime != nil, settings.fNumber != nil, settings.iso != nil { s.correct += 1 }
        }
        Self.report("SC-014 camera data", s, precision: 0.95, coverage: 0.95)
    }

    /// SC-015: brightness reading follows the over/under labels.
    @Test func sc015Brightness() throws {
        guard let set = Self.set() else { print("[SC-015] no test set"); return }
        var s = Score()
        for f in set.frames(where: { $0.labels.exposure != .good }) {
            guard let sample = SceneSample(image: try f.loadImage()) else { continue }
            s.labeled += 1; s.shown += 1
            let ev = ExampleMeasurements(stats: ColorStats(colors: sample.colors)).brightnessEV
            if (f.labels.exposure == .over && ev > 0.3) || (f.labels.exposure == .under && ev < -0.3) { s.correct += 1 }
        }
        Self.report("SC-015 brightness", s, precision: 0.80, coverage: nil)
    }

    /// SC-016: yellow indoor light reads warmer (lower K) than window daylight.
    @Test func sc016Temperature() throws {
        guard let set = Self.set() else { print("[SC-016] no test set"); return }
        func temperature(_ f: TestFrame) throws -> Double? {
            try SceneSample(image: f.loadImage()).flatMap { ExampleMeasurements(stats: ColorStats(colors: $0.colors)).colorTemperature }
        }
        let daylight = try set.frames(where: { $0.labels.light.contains(.windowDaylight) && !$0.labels.light.contains(.warmIndoor) })
            .compactMap(temperature).sorted()
        guard !daylight.isEmpty else { print("[SC-016] no daylight frames"); return }
        let median = daylight[daylight.count / 2]
        var s = Score()
        for f in set.frames(where: { $0.labels.light.contains(.warmIndoor) }) {
            s.labeled += 1
            guard let k = try temperature(f) else { continue }
            s.shown += 1
            if k < median { s.correct += 1 }
        }
        Self.report("SC-016 temperature", s, precision: 0.80, coverage: nil)
    }
}
#endif
