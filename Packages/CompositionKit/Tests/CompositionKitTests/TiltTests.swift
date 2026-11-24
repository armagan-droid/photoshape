import CoreGraphics
import Foundation
import Testing
@testable import CompositionKit

@Suite("Phone tilt against the example's angle (spec 04 cihaz eğimi, spec 05 FR-012)")
struct TiltTests {
    /// Gravity for a phone looking `deg` below the horizon, held in portrait.
    static func gravity(_ deg: Double) -> (Double, Double, Double) {
        let r = deg * .pi / 180
        return (0, -cos(r), -sin(r))
    }

    @Test(arguments: [0.0, 30, 45, 70, 90])
    func readsTheAngle(deg: Double) {
        let g = Self.gravity(deg)
        let a = PhoneTilt.downwardAngle(gravityX: g.0, y: g.1, z: g.2)
        #expect(a.map { abs($0 - deg) < 0.5 } == true)
    }

    @Test func screenDownOrNoReadingIsIgnored() {
        #expect(PhoneTilt.downwardAngle(gravityX: 0, y: 0, z: 1) == nil) // lying screen-down
        #expect(PhoneTilt.downwardAngle(gravityX: 0, y: 0, z: 0) == nil)
    }

    @Test func topDownExampleWantsThePhoneFlat() {
        #expect(PhoneTilt.instruction(downward: 10, example: .topDown)?.kind == "angle.holdFlat")
        #expect(PhoneTilt.instruction(downward: 75, example: .topDown) == nil)
    }

    @Test func angledAndEyeLevel() {
        #expect(PhoneTilt.instruction(downward: 5, example: .angled)?.kind == "angle.tipForward")
        #expect(PhoneTilt.instruction(downward: 40, example: .angled) == nil)
        #expect(PhoneTilt.instruction(downward: 88, example: .angled)?.kind == "angle.raise")
        #expect(PhoneTilt.instruction(downward: 70, example: .eyeLevel)?.kind == "angle.holdUpright")
        #expect(PhoneTilt.instruction(downward: 10, example: .eyeLevel) == nil)
    }

    @Test func unknownAngleOrNoMotionGivesNoHint() {
        #expect(PhoneTilt.instruction(downward: nil, example: .topDown) == nil)
        #expect(PhoneTilt.instruction(downward: 10, example: nil) == nil)
    }

    @Test func angleComesBeforeFraming() {
        let example = Subject(kind: .object, box: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4))
        let small = Subject(kind: .object, box: CGRect(x: 0.45, y: 0.45, width: 0.1, height: 0.1))
        #expect(CompositionGuide.instruction(live: small, example: example, phoneDownward: 5, exampleAngle: .topDown)?.kind == "angle.holdFlat")
        #expect(CompositionGuide.instruction(live: small, example: example, phoneDownward: 85, exampleAngle: .topDown)?.kind == "frame.closer")
        #expect(CompositionGuide.instruction(live: example, example: example, phoneDownward: 85, exampleAngle: .topDown) == nil)
    }
}
