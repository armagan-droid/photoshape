import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Vision

/// Finds the main subject with Apple Vision, on the device (spec 04 FR-K1, Constitution I/V):
/// the largest person (with pose) if there is one, otherwise the most salient object.
public enum SubjectDetector {
    public static func detect(in image: CGImage) -> Subject? {
        detect(handler: VNImageRequestHandler(cgImage: image, options: [:]))
    }

    public static func detect(in buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> Subject? {
        detect(handler: VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation, options: [:]))
    }

    static func detect(handler: VNImageRequestHandler) -> Subject? {
        let poseRequest = VNDetectHumanBodyPoseRequest()
        let saliency = VNGenerateObjectnessBasedSaliencyImageRequest()
        try? handler.perform([poseRequest, saliency])

        let poses = (poseRequest.results ?? []).compactMap(pose(from:))
        if let biggest = poses.compactMap({ p in p.bounds.map { (p, $0) } }).max(by: { $0.1.height < $1.1.height }) {
            return Subject(kind: .person, box: biggest.1, pose: biggest.0)
        }
        let objects = (saliency.results?.first?.salientObjects ?? []).map { flip($0.boundingBox) }
        if let largest = objects.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            return Subject(kind: .object, box: largest)
        }
        return nil
    }

    static let names: [VNHumanBodyPoseObservation.JointName: Joint] = [
        .nose: .nose, .neck: .neck, .leftEye: .leftEye, .rightEye: .rightEye, .leftEar: .leftEar, .rightEar: .rightEar,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder, .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist, .root: .root, .leftHip: .leftHip, .rightHip: .rightHip,
        .leftKnee: .leftKnee, .rightKnee: .rightKnee, .leftAnkle: .leftAnkle, .rightAnkle: .rightAnkle,
    ]

    static func pose(from observation: VNHumanBodyPoseObservation) -> BodyPose? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }
        var joints: [Joint: CGPoint] = [:]
        for (name, point) in points where point.confidence > 0.3 {
            if let joint = names[name] { joints[joint] = CGPoint(x: point.location.x, y: 1 - point.location.y) }
        }
        return joints.count >= 4 ? BodyPose(joints: joints) : nil
    }

    /// Vision boxes have a bottom-left origin.
    static func flip(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: 1 - r.maxY, width: r.width, height: r.height) }
}
