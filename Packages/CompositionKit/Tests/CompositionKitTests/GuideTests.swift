import CoreGraphics
import Testing
@testable import CompositionKit

/// Synthetic poses: a standing person facing the camera (their left arm on image right).
enum Poses {
    /// Arms: angle of shoulder→wrist in degrees, 0 = straight down, 90 = sideways out, 180 = straight up.
    static func person(at center: CGPoint = CGPoint(x: 0.5, y: 0.5), height: CGFloat = 0.6,
                       leftArm: CGFloat = 20, rightArm: CGFloat = 20) -> BodyPose {
        let u = height / 6 // one "unit"
        let neck = CGPoint(x: center.x, y: center.y - 1.6 * u)
        let root = CGPoint(x: center.x, y: center.y + 0.6 * u)
        let ls = CGPoint(x: neck.x + 0.8 * u, y: neck.y), rs = CGPoint(x: neck.x - 0.8 * u, y: neck.y)
        func arm(_ s: CGPoint, _ deg: CGFloat, side: CGFloat) -> (CGPoint, CGPoint) {
            let r = deg * .pi / 180
            let dir = CGVector(dx: side * sin(r), dy: cos(r)) // y down
            return (CGPoint(x: s.x + dir.dx * 1.2 * u, y: s.y + dir.dy * 1.2 * u), CGPoint(x: s.x + dir.dx * 2.4 * u, y: s.y + dir.dy * 2.4 * u))
        }
        let (le, lw) = arm(ls, leftArm, side: 1), (re, rw) = arm(rs, rightArm, side: -1)
        return BodyPose(joints: [
            .nose: CGPoint(x: center.x, y: neck.y - 0.8 * u), .neck: neck, .root: root,
            .leftShoulder: ls, .rightShoulder: rs, .leftElbow: le, .rightElbow: re, .leftWrist: lw, .rightWrist: rw,
            .leftHip: CGPoint(x: root.x + 0.5 * u, y: root.y), .rightHip: CGPoint(x: root.x - 0.5 * u, y: root.y),
            .leftAnkle: CGPoint(x: root.x + 0.5 * u, y: root.y + 2.6 * u), .rightAnkle: CGPoint(x: root.x - 0.5 * u, y: root.y + 2.6 * u),
        ])
    }

    static func subject(_ pose: BodyPose) -> Subject { Subject(kind: .person, box: pose.bounds!, pose: pose) }
}

@Suite("Composition and pose guidance (spec 04 FR-K2, FR-K3, FR-K5, SC-K1)")
struct GuideTests {
    @Test func matchingShotIsReady() {
        let p = Poses.subject(Poses.person())
        #expect(CompositionGuide.instruction(live: p, example: p) == nil)
    }

    @Test func missingPersonComesFirst() {
        let example = Poses.subject(Poses.person())
        #expect(CompositionGuide.instruction(live: nil, example: example)?.kind == "frame.personIn")
        let object = Subject(kind: .object, box: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4))
        #expect(CompositionGuide.instruction(live: object, example: example)?.kind == "frame.personIn")
    }

    @Test func distanceBeforePositionBeforePose() {
        let example = Poses.subject(Poses.person())
        let smallLeftArmUp = Poses.subject(Poses.person(at: CGPoint(x: 0.3, y: 0.5), height: 0.3, leftArm: 170))
        #expect(CompositionGuide.instruction(live: smallLeftArmUp, example: example)?.kind == "frame.closer")
        let offsetArmUp = Poses.subject(Poses.person(at: CGPoint(x: 0.7, y: 0.5), leftArm: 170))
        #expect(CompositionGuide.instruction(live: offsetArmUp, example: example)?.kind == "frame.panRight")
        let armUp = Poses.subject(Poses.person(leftArm: 170))
        #expect(CompositionGuide.instruction(live: armUp, example: example)?.kind == "pose.leftArm.down")
    }

    @Test func tooBigMeansStepBackAndVerticalOffsetMeansTilt() {
        let example = Poses.subject(Poses.person(height: 0.5))
        #expect(CompositionGuide.instruction(live: Poses.subject(Poses.person(height: 0.8)), example: example)?.kind == "frame.farther")
        let low = Poses.subject(Poses.person(at: CGPoint(x: 0.5, y: 0.68), height: 0.5))
        #expect(CompositionGuide.instruction(live: low, example: example)?.kind == "frame.tiltDown")
    }

    /// SC-K1: same pose at another place and size is similar; one different arm is the one named.
    @Test(arguments: [(CGFloat(20), CGFloat(110)), (90, 170), (170, 30), (45, 100)])
    func namesTheArmThatDiffers(exampleAngle: CGFloat, liveAngle: CGFloat) {
        let example = Poses.person(rightArm: exampleAngle)
        let live = Poses.person(rightArm: liveAngle)
        let hint = CompositionGuide.poseInstruction(live: live, example: example, threshold: 28)
        #expect(hint?.kind == "pose.rightArm.\(exampleAngle > liveAngle ? "up" : "down")")
    }

    // MARK: - Head, torso, legs (spec 04 K2.1, 2026-11-24)

    static func with(_ pose: BodyPose, _ change: (inout [Joint: CGPoint]) -> Void) -> BodyPose {
        var j = pose.joints
        change(&j)
        return BodyPose(joints: j)
    }

    /// Eyes level, or turned by `deg` toward the person's own left shoulder (image right when facing the camera).
    static func headTilted(_ deg: CGFloat, base: BodyPose = Poses.person()) -> BodyPose {
        with(base) { j in
            let c = j[.nose]!, r = deg * .pi / 180, half: CGFloat = 0.03
            j[.leftEye] = CGPoint(x: c.x + half * cos(r), y: c.y + half * sin(r))
            j[.rightEye] = CGPoint(x: c.x - half * cos(r), y: c.y - half * sin(r))
        }
    }

    @Test(arguments: [(CGFloat(20), "pose.head.left"), (-20, "pose.head.right")])
    func namesTheHeadTilt(exampleTilt: CGFloat, expected: String) {
        let hint = CompositionGuide.poseInstruction(live: Self.headTilted(0), example: Self.headTilted(exampleTilt))
        #expect(hint?.kind == expected)
        #expect(CompositionGuide.poseInstruction(live: Self.headTilted(5), example: Self.headTilted(0)) == nil, "small tilts are fine")
    }

    @Test func headTiltIsMeasuredAgainstTheShoulders() {
        // The whole person turned 10° (phone held a little crooked): no head hint.
        func rotated(_ p: BodyPose, _ deg: CGFloat) -> BodyPose {
            let r = deg * .pi / 180, c = CGPoint(x: 0.5, y: 0.5)
            return BodyPose(joints: p.joints.mapValues { q in
                CGPoint(x: c.x + (q.x - c.x) * cos(r) - (q.y - c.y) * sin(r), y: c.y + (q.x - c.x) * sin(r) + (q.y - c.y) * cos(r))
            })
        }
        let tilt = CompositionGuide.headTilt(rotated(Self.headTilted(0), 10))!
        #expect(abs(tilt) < 1)
    }

    @Test func namesTheTorsoLean() {
        let upright = Poses.person()
        // Neck moved toward image right = the person's own left when facing the camera.
        let leaning = Self.with(upright) { j in j[.neck]!.x += 0.06 }
        #expect(CompositionGuide.poseInstruction(live: upright, example: leaning)?.kind == "pose.torso.left")
        #expect(CompositionGuide.poseInstruction(live: leaning, example: upright)?.kind == "pose.torso.right")
    }

    @Test func namesTheLegThatDiffers() {
        let together = Poses.person()
        let leftOut = Self.with(together) { j in j[.leftAnkle]!.x += 0.12 } // left side is image right
        #expect(CompositionGuide.poseInstruction(live: together, example: leftOut)?.kind == "pose.leftLeg.out")
        #expect(CompositionGuide.poseInstruction(live: leftOut, example: together)?.kind == "pose.leftLeg.in")
        let rightOut = Self.with(together) { j in j[.rightAnkle]!.x -= 0.12 }
        #expect(CompositionGuide.poseInstruction(live: together, example: rightOut)?.kind == "pose.rightLeg.out")
    }

    @Test func theBiggestDifferenceIsNamed() {
        // Arm 40° off (1.4× its limit) and head 30° off (2.5× its limit): the head comes first.
        let example = Self.headTilted(30, base: Poses.person(leftArm: 60))
        let live = Self.headTilted(0, base: Poses.person(leftArm: 20))
        #expect(CompositionGuide.poseInstruction(live: live, example: example)?.kind == "pose.head.left")
    }

    @Test func missingJointsGiveNoHint() {
        let noEyes = Poses.person(), noLegs = Self.with(Poses.person()) { j in j[.leftAnkle] = nil; j[.rightAnkle] = nil }
        #expect(CompositionGuide.headTilt(noEyes) == nil)
        #expect(CompositionGuide.legSpread(noLegs, hip: .leftHip, ankle: .leftAnkle) == nil)
        #expect(CompositionGuide.poseInstruction(live: noLegs, example: Poses.person()) == nil)
    }

    @Test func similarityIgnoresPlaceAndScale() {
        let a = Poses.person(at: CGPoint(x: 0.3, y: 0.4), height: 0.4, leftArm: 90, rightArm: 150)
        let b = Poses.person(at: CGPoint(x: 0.6, y: 0.6), height: 0.8, leftArm: 90, rightArm: 150)
        #expect(CompositionGuide.similarity(a, b) > 0.98)
        #expect(CompositionGuide.similarity(a, Poses.person(leftArm: 0, rightArm: 0)) < 0.6)
    }

    @Test func exampleOfAnotherAspectIsFittedIntoTheFrame() {
        let square = exampleRegion(exampleAspect: 1)
        #expect(abs(square.height - 0.8) < 1e-9 && abs(square.minY - 0.1) < 1e-9 && square.width == 1)
        let tall = exampleRegion(exampleAspect: 9.0 / 16)
        #expect(tall.height == 1 && tall.width < 1)
        let s = Subject(kind: .object, box: CGRect(x: 0, y: 0, width: 1, height: 1)).placed(in: square)
        #expect(s.box == square)
        let back = s.cropped(to: square)
        #expect(abs(back.box.width - 1) < 1e-9 && abs(back.box.minY) < 1e-9)
    }
}
