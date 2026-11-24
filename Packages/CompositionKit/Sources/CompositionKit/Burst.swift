import CoreGraphics
import Foundation
import Vision

/// One press, several frames, the best one kept (spec 06). Pure scoring and choice, tested on macOS (FR-001);
/// the camera supplies the frames, Vision the eyes.

// MARK: - Sharpness

public enum Sharpness {
    /// Long side the frame is measured at: enough for hand shake, quick on the phone (FR-003).
    static let measureSide = 384

    /// Variance of the Laplacian on the subject (FR-002): a background blurred on purpose does not count.
    /// Nil subject: the middle of the frame.
    public static func measure(_ image: CGImage, subject: CGRect?) -> Double {
        let scale = Double(measureSide) / Double(max(image.width, image.height))
        let w = max(8, Int(Double(image.width) * scale)), h = max(8, Int(Double(image.height) * scale))
        var px = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return 0 }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let region = (subject ?? CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return laplacianVariance(px.map { Double($0) / 255 }, width: w, height: h, region: region.isNull ? CGRect(x: 0, y: 0, width: 1, height: 1) : region)
    }

    /// Row 0 is the top; `region` normalized with the origin at the top left.
    static func laplacianVariance(_ g: [Double], width w: Int, height h: Int, region: CGRect) -> Double {
        let x0 = max(1, Int(region.minX * Double(w))), x1 = min(w - 1, Int(region.maxX * Double(w)))
        let y0 = max(1, Int(region.minY * Double(h))), y1 = min(h - 1, Int(region.maxY * Double(h)))
        guard x1 > x0 + 2, y1 > y0 + 2 else { return 0 }
        var sum = 0.0, sum2 = 0.0, n = 0.0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let c = g[y * w + x]
                let l = g[(y - 1) * w + x] + g[(y + 1) * w + x] + g[y * w + x - 1] + g[y * w + x + 1] - 4 * c
                sum += l; sum2 += l * l; n += 1
            }
        }
        let mean = sum / n
        return sum2 / n - mean * mean
    }
}

// MARK: - Eyes

public struct FaceEyes: Sendable, Hashable {
    /// Height / width of each eye's outline; nil when Vision did not find that eye.
    public var left: Double?
    public var right: Double?
    public init(left: Double?, right: Double?) { self.left = left; self.right = right }

    /// Closed when the open eyes we can see are thinner than this (spec 06 açık soru 3: derived from the eye points).
    public static let closedBelow = 0.17

    public var isClosed: Bool {
        let seen = [left, right].compactMap { $0 }
        guard !seen.isEmpty else { return false }
        return seen.max()! < Self.closedBelow
    }

    /// Height / width of an eye outline (Vision gives 6–8 points around the eye).
    public static func openness(_ outline: [CGPoint]) -> Double? {
        guard outline.count >= 4, let minX = outline.map(\.x).min(), let maxX = outline.map(\.x).max(),
              let minY = outline.map(\.y).min(), let maxY = outline.map(\.y).max(), maxX - minX > 1e-6 else { return nil }
        return Double((maxY - minY) / (maxX - minX))
    }

    /// Faces and their eyes with Vision, on the device.
    public static func detect(in image: CGImage) -> [FaceEyes] {
        let request = VNDetectFaceLandmarksRequest()
        guard (try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])) != nil else { return [] }
        return (request.results ?? []).compactMap { face in
            guard let landmarks = face.landmarks else { return nil }
            func open(_ region: VNFaceLandmarkRegion2D?) -> Double? {
                region.flatMap { openness($0.normalizedPoints.map { CGPoint(x: $0.x, y: $0.y) }) }
            }
            return FaceEyes(left: open(landmarks.leftEye), right: open(landmarks.rightEye))
        }
    }
}

// MARK: - Choice

public struct FrameQuality: Sendable, Hashable {
    public var sharpness: Double
    public var faces: [FaceEyes]
    public init(sharpness: Double, faces: [FaceEyes] = []) { self.sharpness = sharpness; self.faces = faces }
    public var openFaces: Int { faces.filter { !$0.isClosed }.count }
    public var closedFaces: Int { faces.filter(\.isClosed).count }
}

public struct BurstSelection: Sendable, Hashable {
    public enum Reason: String, Sendable { case sharp, motionBlur = "motion_blur", eyesClosed = "eyes_closed", only }
    public var index: Int
    /// Why the others lost, for diagnostics (FR-001).
    public var reason: Reason
    /// Every frame was blurred: tell the user to hold the phone still (Hikâye 1.3).
    public var allBlurred: Bool
}

public enum BurstSelector {
    /// Below this share of the best frame's sharpness a frame counts as blurred against it.
    static let blurredShare = 0.6
    /// Absolute floor for "the whole series is blurred" (Laplacian variance at the measuring size).
    public static let blurredBelow = 0.0012

    /// Hikâye 2: with open eyes available, no frame with closed eyes wins; with nobody fully open, the most open eyes.
    /// Then the sharpest (Hikâye 1). Deterministic: ties go to the earliest frame.
    public static func choose(_ frames: [FrameQuality]) -> BurstSelection? {
        guard !frames.isEmpty else { return nil }
        guard frames.count > 1 else {
            return BurstSelection(index: 0, reason: .only, allBlurred: frames[0].sharpness < blurredBelow)
        }
        let indices = Array(frames.indices)
        let anyAllOpen = indices.filter { frames[$0].closedFaces == 0 }
        let candidates: [Int]
        if !anyAllOpen.isEmpty { candidates = anyAllOpen }
        else {
            let best = frames.map(\.openFaces).max()!
            candidates = indices.filter { frames[$0].openFaces == best }
        }
        let pick = candidates.max { a, b in frames[a].sharpness < frames[b].sharpness || (frames[a].sharpness == frames[b].sharpness && a > b) }!
        let eyesMattered = candidates.count < frames.count
        let sharpest = frames.map(\.sharpness).max()!
        let reason: BurstSelection.Reason = eyesMattered ? .eyesClosed
            : frames.contains { $0.sharpness < sharpest * blurredShare } ? .motionBlur : .sharp
        return BurstSelection(index: pick, reason: reason, allBlurred: sharpest < blurredBelow)
    }
}

// MARK: - When to shoot a series (Hikâye 4, FR-004; open question 1 default)

public enum BurstPlan {
    public static let seriesLength = 3

    /// A person (blinks, moves), a moving phone or a dim scene → a short series; a still plate → one frame.
    /// Memory pressure or heat → one frame, silently (uç durum).
    public static func frameCount(hasPerson: Bool, phoneRotation: Double, isDim: Bool, isConstrained: Bool) -> Int {
        guard !isConstrained else { return 1 }
        return hasPerson || phoneRotation > 0.35 || isDim ? seriesLength : 1
    }
}
