import CoreGraphics
import Testing
@testable import CompositionKit

@Suite("Light advice (spec 04 FR-L1…L4)")
struct LightTests {
    static let box = CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.5)

    /// 40×50 grid: background level `bg`, subject box with left/right halves.
    static func grid(bg: Double, left: Double, right: Double) -> LuminanceGrid {
        let w = 40, h = 50
        var v = [Double](repeating: bg, count: w * h)
        for y in 0..<h { for x in 0..<w {
            let fx = (Double(x) + 0.5) / Double(w), fy = (Double(y) + 0.5) / Double(h)
            if box.contains(CGPoint(x: fx, y: fy)) { v[y * w + x] = fx < box.midX ? left : right }
        } }
        return LuminanceGrid(width: w, height: h, values: v)
    }

    @Test func readsBacklightAndSide() throws {
        let backlit = try #require(LightAnalyzer.read(Self.grid(bg: 0.9, left: 0.3, right: 0.3), subject: Self.box))
        #expect(backlit.subjectToBackground < 0.4)
        let leftLit = try #require(LightAnalyzer.read(Self.grid(bg: 0.4, left: 0.8, right: 0.4), subject: Self.box))
        #expect(leftLit.sideBalance < -0.2)
        let even = try #require(LightAnalyzer.read(Self.grid(bg: 0.5, left: 0.5, right: 0.5), subject: Self.box))
        #expect(abs(even.sideBalance) < 0.01 && abs(even.subjectToBackground - 1) < 0.01)
    }

    @Test func backlitComesBeforeFramingUnlessTheExampleIsBacklitToo() {
        let example = Poses.subject(Poses.person())
        let tooSmall = Poses.subject(Poses.person(height: 0.3))
        let backlit = LightReading(subjectToBackground: 0.3, sideBalance: 0)
        let normal = LightReading(subjectToBackground: 1, sideBalance: 0)
        #expect(CompositionGuide.instruction(live: tooSmall, example: example,
                                             light: .init(live: backlit, example: normal, isDim: false))?.kind == "light.backlit")
        #expect(CompositionGuide.instruction(live: tooSmall, example: example,
                                             light: .init(live: backlit, example: backlit, isDim: false))?.kind == "frame.closer",
                "a silhouette example is not corrected")
        #expect(CompositionGuide.instruction(live: nil, example: example,
                                             light: .init(live: backlit, example: normal, isDim: true))?.kind == "frame.personIn",
                "getting the person in frame still comes first")
    }

    @Test func dimComesFromTheCamera() {
        let p = Poses.subject(Poses.person())
        #expect(CompositionGuide.instruction(live: p, example: p, light: .init(live: nil, example: nil, isDim: true))?.kind == "light.dim")
    }

    @Test func sideLightIsTheLastTouch() {
        let p = Poses.subject(Poses.person())
        let fromLeft = LightReading(subjectToBackground: 1, sideBalance: -0.3)
        let flat = LightReading(subjectToBackground: 1, sideBalance: 0)
        let fromRight = LightReading(subjectToBackground: 1, sideBalance: 0.3)
        #expect(CompositionGuide.instruction(live: p, example: p, light: .init(live: flat, example: fromLeft, isDim: false))?.kind == "light.fromLeft")
        #expect(CompositionGuide.instruction(live: p, example: p, light: .init(live: fromRight, example: fromLeft, isDim: false))?.kind == "light.fromLeft")
        #expect(CompositionGuide.instruction(live: p, example: p, light: .init(live: fromLeft, example: fromLeft, isDim: false)) == nil)
        #expect(CompositionGuide.instruction(live: p, example: p, light: .init(live: fromRight, example: flat, isDim: false)) == nil,
                "no side light in the example, no advice")
        // Pose problems come before light direction.
        let armUp = Poses.subject(Poses.person(leftArm: 170))
        #expect(CompositionGuide.instruction(live: armUp, example: p, light: .init(live: flat, example: fromLeft, isDim: false))?.kind == "pose.leftArm.down")
    }
}
