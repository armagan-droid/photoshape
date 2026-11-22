import CoreGraphics
import Foundation
import Testing
@testable import CompositionKit

@Suite("Smart exposure (spec 02 FR-002, FR-009)")
struct ExposureTests {
    static let box = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)

    /// A scene in linear light; `render` exposes it with a bias and gamma-encodes it, like the camera would.
    struct Scene {
        var background: Double
        var subject: Double
        var subjectHighlight: Double? = nil // a small bright spot inside the subject

        func grid(bias: Double) -> LuminanceGrid {
            let w = 40, h = 50
            var v: [Double] = []
            for y in 0..<h { for x in 0..<w {
                let fx = (Double(x) + 0.5) / Double(w), fy = (Double(y) + 0.5) / Double(h)
                var lin = background
                if ExposureTests.box.contains(CGPoint(x: fx, y: fy)) {
                    lin = subject
                    if let spot = subjectHighlight, fx > 0.6, fy < 0.42 { lin = spot }
                }
                v.append(gammaEncode(min(1, lin * pow(2, bias))))
            } }
            return LuminanceGrid(width: w, height: h, values: v)
        }
    }

    static func gammaEncode(_ c: Double) -> Double { c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055 }

    /// Runs the camera loop: decide, apply, look again.
    static func settle(_ scene: Scene, exampleOffset: Double = 0, rounds: Int = 15) -> (bias: Double, history: [Double], last: ExposureDecider.Decision) {
        var bias = 0.0, history: [Double] = []
        var d = ExposureDecider.Decision(bias: 0, meteringPoint: nil, reason: .none)
        for _ in 0..<rounds {
            d = ExposureDecider.decide(grid: scene.grid(bias: bias), subject: box, currentBias: bias, exampleOffset: exampleOffset)
            bias = d.bias; history.append(bias)
        }
        return (bias, history, d)
    }

    @Test func backlitSubjectIsBrought() {
        // Window behind a dark cup: the auto exposure made the subject dark.
        let r = Self.settle(Scene(background: 0.9, subject: 0.03))
        #expect(r.bias > 1, "bias \(r.bias)")
        #expect(r.last.reason == .subjectBrightened)
        let subject = ExposureDecider.decide(grid: Scene(background: 0.9, subject: 0.03).grid(bias: r.bias), subject: Self.box, currentBias: r.bias)
        #expect(subject.bias == r.bias, "settled")
    }

    @Test func wellExposedSubjectIsLeftAlone() {
        let r = Self.settle(Scene(background: 0.2, subject: 0.18))
        #expect(abs(r.bias) < 0.3)
        #expect(r.last.reason == .none)
    }

    @Test func brightSubjectIsDarkenedNotClipped() {
        let r = Self.settle(Scene(background: 0.3, subject: 0.85))
        #expect(r.bias < -0.5)
        #expect(r.last.reason == .subjectDarkened)
    }

    @Test func highlightsInTheSubjectLimitBrightening() {
        // Dark subject with a white spot (a plate rim): it may not be pushed into white.
        let r = Self.settle(Scene(background: 0.1, subject: 0.03, subjectHighlight: 0.5))
        let spot = r.history.isEmpty ? 0 : 0.5 * pow(2, r.bias)
        #expect(spot <= ExposureDecider.linear(ExposureDecider.highlightLimit) * 1.1, "spot reaches \(spot)")
        #expect(r.last.reason == .highlightsProtected)
    }

    @Test func convergesWithoutOscillating() {
        let r = Self.settle(Scene(background: 0.6, subject: 0.02), rounds: 20)
        let steps = zip(r.history.dropFirst(), r.history).map { $0 - $1 }
        #expect(steps.allSatisfy { $0 >= -1e-9 }, "only goes one way: \(r.history)")
    }

    @Test func examplePreferenceShiftsTheTarget() {
        let plain = Self.settle(Scene(background: 0.2, subject: 0.18)).bias
        let brighter = Self.settle(Scene(background: 0.2, subject: 0.18), exampleOffset: 0.8).bias
        #expect(brighter > plain + 0.4)
        #expect(ExposureDecider.biasRange.contains(brighter))
    }

    @Test func metersOnTheSubject() {
        let d = ExposureDecider.decide(grid: Scene(background: 0.5, subject: 0.2).grid(bias: 0), subject: Self.box, currentBias: 0)
        #expect(d.meteringPoint == CGPoint(x: Self.box.midX, y: Self.box.midY))
    }
}
