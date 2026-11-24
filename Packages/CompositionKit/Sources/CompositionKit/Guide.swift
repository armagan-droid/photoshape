import CoreGraphics
import FrameKit
import Foundation

/// Compares the live subject with the example and returns the single most important correction
/// (spec 04 FR-K2, FR-K3, FR-K5), or nil when the shot matches ("hazır"). Pure and deterministic.
public enum CompositionGuide {
    public struct Thresholds: Sendable {
        /// Live subject height / example height outside this range → closer / farther.
        public var size: ClosedRange<CGFloat> = 0.82...1.22
        /// Center offset (fraction of the frame) that triggers a pan / tilt hint.
        public var offset: CGFloat = 0.09
        /// Arm angle difference (degrees) that triggers a pose hint.
        public var armAngle: CGFloat = 28
        /// Head tilt against the shoulders and torso lean, degrees.
        public var headTilt: CGFloat = 12
        public var torsoLean: CGFloat = 12
        /// How far an ankle is out from the body's middle, in torso lengths.
        public var legSpread: CGFloat = 0.35
        public init() {}
    }

    /// - Parameters:
    ///   - phoneDownward: how far the phone looks down (`PhoneTilt.downwardAngle`), nil without motion data.
    ///   - exampleAngle: the example's shooting angle when it was read with confidence (spec 05 FR-012).
    public static func instruction(live: Subject?, example: Subject, light: LightContext? = nil,
                                   phoneDownward: Double? = nil, exampleAngle: ShotAngle? = nil,
                                   thresholds t: Thresholds = .init()) -> GuidanceInstruction? {
        // The angle comes first: from the wrong height, the subject's place and size cannot match anyway.
        if let angle = PhoneTilt.instruction(downward: phoneDownward, example: exampleAngle) { return angle }

        guard let live, live.kind == example.kind || example.kind == .object else {
            return example.kind == .person
                ? GuidanceInstruction(kind: "frame.personIn", priority: 0, phraseKey: "guide.personIn")
                : GuidanceInstruction(kind: "frame.subjectIn", priority: 0, phraseKey: "guide.subjectIn")
        }

        if let problem = lightProblem(light) { return problem }

        let ratio = live.box.height / max(example.box.height, 0.01)
        if ratio < t.size.lowerBound { return GuidanceInstruction(kind: "frame.closer", direction: .closer, priority: 1, phraseKey: "guide.closer") }
        if ratio > t.size.upperBound { return GuidanceInstruction(kind: "frame.farther", direction: .farther, priority: 1, phraseKey: "guide.farther") }

        // Subject right of where it should be → turn the phone right (the subject then moves left in the frame).
        let dx = live.box.midX - example.box.midX, dy = live.box.midY - example.box.midY
        if abs(dx) >= abs(dy), abs(dx) > t.offset {
            return dx > 0 ? GuidanceInstruction(kind: "frame.panRight", direction: .right, priority: 2, phraseKey: "guide.panRight")
                          : GuidanceInstruction(kind: "frame.panLeft", direction: .left, priority: 2, phraseKey: "guide.panLeft")
        }
        if abs(dy) > t.offset {
            return dy > 0 ? GuidanceInstruction(kind: "frame.tiltDown", direction: .down, priority: 2, phraseKey: "guide.tiltDown")
                          : GuidanceInstruction(kind: "frame.tiltUp", direction: .up, priority: 2, phraseKey: "guide.tiltUp")
        }

        if example.kind == .person, let a = live.pose, let b = example.pose, let pose = poseInstruction(live: a, example: b, thresholds: t) {
            return pose
        }
        return lightDirection(light)
    }

    /// Every sentence the guide can show (checked against the String Catalog, Constitution VI).
    public static var allPhraseKeys: [String] {
        ["guide.personIn", "guide.subjectIn", "guide.closer", "guide.farther", "guide.panLeft", "guide.panRight",
         "guide.tiltUp", "guide.tiltDown", "guide.light.backlit", "guide.light.dim", "guide.light.fromLeft", "guide.light.fromRight"]
            + ["leftArm", "rightArm"].flatMap { a in ["up", "down"].map { "guide.\(a).\($0)" } }
            + ["leftLeg", "rightLeg"].flatMap { l in ["out", "in"].map { "guide.\(l).\($0)" } }
            + ["torso", "head"].flatMap { p in ["left", "right"].map { "guide.\(p).\($0)" } }
            + PhoneTilt.allPhraseKeys
    }

    // MARK: - Pose

    /// Arm segments compared, most visible first.
    static let arms: [(name: String, from: Joint, to: Joint, end: Joint)] = [
        ("leftArm", .leftShoulder, .leftElbow, .leftWrist),
        ("rightArm", .rightShoulder, .rightElbow, .rightWrist),
    ]

    /// How similar two poses are, 0…1, independent of where the person is and how big (SC-K1).
    public static func similarity(_ a: BodyPose, _ b: BodyPose) -> Double {
        let diffs = arms.compactMap { armAngleDifference(a, b, $0.from, $0.end) }
        guard !diffs.isEmpty else { return 0 }
        let mean = diffs.reduce(0, +) / CGFloat(diffs.count)
        return Double(max(0, 1 - mean / 90))
    }

    /// The single most different body part (spec 04 K2.1): arms, legs, torso lean, head tilt. Each difference is
    /// measured against its own threshold, and the one furthest past it is named. Left and right are the person's own.
    static func poseInstruction(live: BodyPose, example: BodyPose, thresholds t: Thresholds = .init()) -> GuidanceInstruction? {
        var candidates: [(score: CGFloat, instruction: GuidanceInstruction)] = []
        func add(_ score: CGFloat, _ name: String, _ action: String, _ direction: GuidanceInstruction.Direction?) {
            guard score > 1 else { return }
            candidates.append((score, GuidanceInstruction(kind: "pose.\(name).\(action)", direction: direction, priority: 3,
                                                          phraseKey: "guide.\(name).\(action)")))
        }
        for arm in arms {
            guard let diff = armAngleDifference(live, example, arm.from, arm.end),
                  let raise = shouldRaise(live: live, example: example, shoulder: arm.from, wrist: arm.end) else { continue }
            add(diff / t.armAngle, arm.name, raise ? "up" : "down", raise ? .up : .down)
        }
        for leg in legs {
            guard let l = legSpread(live, hip: leg.hip, ankle: leg.ankle), let e = legSpread(example, hip: leg.hip, ankle: leg.ankle) else { continue }
            add(abs(e - l) / t.legSpread, leg.name, e > l ? "out" : "in", nil)
        }
        if let l = torsoLean(live), let e = torsoLean(example) {
            add(abs(e - l) / t.torsoLean, "torso", e > l ? "left" : "right", nil)
        }
        if let l = headTilt(live), let e = headTilt(example) {
            add(abs(e - l) / t.headTilt, "head", e > l ? "left" : "right", nil)
        }
        return candidates.max { $0.score < $1.score }?.instruction
    }

    static func poseInstruction(live: BodyPose, example: BodyPose, threshold: CGFloat) -> GuidanceInstruction? {
        var t = Thresholds()
        t.armAngle = threshold
        return poseInstruction(live: live, example: example, thresholds: t)
    }

    static let legs: [(name: String, hip: Joint, ankle: Joint)] = [("leftLeg", .leftHip, .leftAnkle), ("rightLeg", .rightHip, .rightAnkle)]

    /// Ankle's distance out from the body's middle, in torso lengths; positive = away from the other leg.
    static func legSpread(_ p: BodyPose, hip: Joint, ankle: Joint) -> CGFloat? {
        let other: Joint = hip == .leftHip ? .rightHip : .leftHip
        guard let h = p.joints[hip], let o = p.joints[other], let a = p.joints[ankle] else { return nil }
        let middle = p.joints[.root]?.x ?? (h.x + o.x) / 2
        let outward: CGFloat = h.x >= o.x ? 1 : -1
        return (a.x - middle) * outward / max(torso(p), 0.01)
    }

    /// Lean of the upper body, degrees; positive = toward the person's own left (their left hip side).
    static func torsoLean(_ p: BodyPose) -> CGFloat? {
        guard let n = p.joints[.neck], let r = p.joints[.root], let lh = p.joints[.leftHip], let rh = p.joints[.rightHip] else { return nil }
        let toLeft: CGFloat = lh.x >= rh.x ? 1 : -1
        return atan2((n.x - r.x) * toLeft, r.y - n.y) * 180 / .pi
    }

    /// Head tilt against the shoulder line, degrees; positive = toward the person's own left shoulder.
    /// Measured against the shoulders, so holding the phone a little crooked does not count.
    static func headTilt(_ p: BodyPose) -> CGFloat? {
        let head: (CGPoint, CGPoint)?
        if let l = p.joints[.leftEye], let r = p.joints[.rightEye] { head = (l, r) }
        else if let l = p.joints[.leftEar], let r = p.joints[.rightEar] { head = (l, r) }
        else { head = nil }
        guard let (le, re) = head, let ls = p.joints[.leftShoulder], let rs = p.joints[.rightShoulder] else { return nil }
        func angle(_ from: CGPoint, _ to: CGPoint) -> CGFloat { atan2(to.y - from.y, to.x - from.x) * 180 / .pi }
        // Facing the camera the left side is on image right, so right → left points right; y grows downward,
        // so a left eye lower than the right one (head toward the left shoulder) gives a positive angle.
        let flip: CGFloat = ls.x >= rs.x ? 1 : -1
        var d = (angle(re, le) - angle(rs, ls)) * flip
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    /// Angle (degrees) between the shoulder→wrist directions of two poses.
    static func armAngleDifference(_ a: BodyPose, _ b: BodyPose, _ from: Joint, _ to: Joint) -> CGFloat? {
        guard let a1 = a.joints[from], let a2 = a.joints[to], let b1 = b.joints[from], let b2 = b.joints[to] else { return nil }
        let va = CGVector(dx: a2.x - a1.x, dy: a2.y - a1.y), vb = CGVector(dx: b2.x - b1.x, dy: b2.y - b1.y)
        let la = hypot(va.dx, va.dy), lb = hypot(vb.dx, vb.dy)
        guard la > 1e-4, lb > 1e-4 else { return nil }
        let cos = max(-1, min(1, (va.dx * vb.dx + va.dy * vb.dy) / (la * lb)))
        return acos(cos) * 180 / .pi
    }

    /// Whether the wrist should go up relative to the shoulder, measured in body lengths so distance does not matter.
    static func shouldRaise(live: BodyPose, example: BodyPose, shoulder: Joint, wrist: Joint) -> Bool? {
        func height(_ p: BodyPose) -> CGFloat? {
            guard let s = p.joints[shoulder], let w = p.joints[wrist] else { return nil }
            return (s.y - w.y) / max(torso(p), 0.01) // positive when the wrist is above the shoulder (y grows downward)
        }
        guard let l = height(live), let e = height(example) else { return nil }
        return e > l
    }

    static func torso(_ p: BodyPose) -> CGFloat {
        if let n = p.joints[.neck], let r = p.joints[.root] { return hypot(n.x - r.x, n.y - r.y) }
        if let ls = p.joints[.leftShoulder], let rs = p.joints[.rightShoulder] { return hypot(ls.x - rs.x, ls.y - rs.y) * 1.6 }
        return 0.2
    }
}
