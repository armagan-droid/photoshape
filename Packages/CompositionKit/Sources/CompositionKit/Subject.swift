import CoreGraphics
import Foundation

/// Body joints, named from the person's own point of view (their left arm is `leftShoulder` → `leftWrist`).
public enum Joint: String, CaseIterable, Codable, Sendable {
    case nose, neck, leftEye, rightEye, leftEar, rightEar
    case leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist
    case root, leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle
}

/// A pose as joint positions, normalized to the frame (0–1, origin top-left).
public struct BodyPose: Codable, Sendable, Hashable {
    public var joints: [Joint: CGPoint]
    public init(joints: [Joint: CGPoint]) { self.joints = joints }

    /// Box around the body without the arms, padded so it roughly covers the person. Arms are left out so that
    /// raising an arm does not look like the person getting bigger (framing must not depend on the pose).
    public var bounds: CGRect? {
        let arms: Set<Joint> = [.leftElbow, .rightElbow, .leftWrist, .rightWrist]
        let pts = joints.filter { !arms.contains($0.key) }.map(\.value)
        guard pts.count >= 3, let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else { return nil }
        let w = maxX - minX, h = maxY - minY
        return CGRect(x: minX - w * 0.15, y: minY - h * 0.12, width: w * 1.3, height: h * 1.24)
    }
}

/// The main subject of a frame: a person with a pose, or the most salient object.
public struct Subject: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable { case person, object }
    public var kind: Kind
    /// Normalized box, origin top-left, in the coordinates of the frame it was found in.
    public var box: CGRect
    public var pose: BodyPose?

    public init(kind: Kind, box: CGRect, pose: BodyPose? = nil) { self.kind = kind; self.box = box; self.pose = pose }

    /// The same subject expressed in another frame: `region` is where this frame sits inside that frame (normalized).
    public func placed(in region: CGRect) -> Subject {
        func map(_ p: CGPoint) -> CGPoint { CGPoint(x: region.minX + p.x * region.width, y: region.minY + p.y * region.height) }
        let b = CGRect(origin: map(box.origin), size: CGSize(width: box.width * region.width, height: box.height * region.height))
        let posed = pose.map { BodyPose(joints: $0.joints.mapValues(map)) }
        return Subject(kind: kind, box: b, pose: posed)
    }

    /// The same subject seen through a crop: `crop` is the cropped area of this frame (normalized).
    public func cropped(to crop: CGRect) -> Subject {
        func map(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - crop.minX) / crop.width, y: (p.y - crop.minY) / crop.height) }
        let b = CGRect(origin: map(box.origin), size: CGSize(width: box.width / crop.width, height: box.height / crop.height))
        return Subject(kind: kind, box: b, pose: pose.map { BodyPose(joints: $0.joints.mapValues(map)) })
    }
}

/// Where an example of the given aspect sits inside the 4:5 output frame (aspect-fit, centered).
/// The ghost overlay and the comparison both use it, so what the user aligns with is what is compared.
public func exampleRegion(exampleAspect: CGFloat, frameAspect: CGFloat = 4.0 / 5.0) -> CGRect {
    guard exampleAspect > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
    if exampleAspect >= frameAspect {
        let h = frameAspect / exampleAspect
        return CGRect(x: 0, y: (1 - h) / 2, width: 1, height: h)
    } else {
        let w = exampleAspect / frameAspect
        return CGRect(x: (1 - w) / 2, y: 0, width: w, height: 1)
    }
}
