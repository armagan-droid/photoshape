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
        public init() {}
    }

    public static func instruction(live: Subject?, example: Subject, thresholds t: Thresholds = .init()) -> GuidanceInstruction? {
        guard let live, live.kind == example.kind || example.kind == .object else {
            return example.kind == .person
                ? GuidanceInstruction(kind: "frame.personIn", priority: 0, phraseKey: "guide.personIn")
                : GuidanceInstruction(kind: "frame.subjectIn", priority: 0, phraseKey: "guide.subjectIn")
        }

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

        if example.kind == .person, let a = live.pose, let b = example.pose, let pose = poseInstruction(live: a, example: b, threshold: t.armAngle) {
            return pose
        }
        return nil
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

    static func poseInstruction(live: BodyPose, example: BodyPose, threshold: CGFloat) -> GuidanceInstruction? {
        var worst: (name: String, diff: CGFloat, raise: Bool)?
        for arm in arms {
            guard let diff = armAngleDifference(live, example, arm.from, arm.end), diff > threshold,
                  let raise = shouldRaise(live: live, example: example, shoulder: arm.from, wrist: arm.end) else { continue }
            if diff > (worst?.diff ?? 0) { worst = (arm.name, diff, raise) }
        }
        guard let w = worst else { return nil }
        let action = w.raise ? "up" : "down"
        return GuidanceInstruction(kind: "pose.\(w.name).\(action)", direction: w.raise ? .up : .down, priority: 3,
                                   phraseKey: "guide.\(w.name).\(action)")
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
