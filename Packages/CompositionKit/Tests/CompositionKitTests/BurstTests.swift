import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import CompositionKit

@Suite("Series and the best frame (spec 06 FR-001, FR-002, SC-001, SC-002 synthetic)")
struct BurstTests {
    /// A textured scene (checkerboard), optionally blurred all over or only outside the middle.
    static func scene(blur: Double = 0, backgroundBlur: Double = 0) -> CGImage {
        let ctx = CGContext(data: nil, width: 600, height: 750, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for y in stride(from: 0, to: 750, by: 10) { for x in stride(from: 0, to: 600, by: 10) {
            let v: CGFloat = ((x / 10 + y / 10) % 2 == 0) ? 0.85 : 0.2
            ctx.setFillColor(CGColor(red: v, green: v, blue: v, alpha: 1)); ctx.fill(CGRect(x: x, y: y, width: 10, height: 10))
        } }
        var image = CIImage(cgImage: ctx.makeImage()!)
        let extent = image.extent
        if blur > 0 { image = image.clampedToExtent().applyingGaussianBlur(sigma: blur).cropped(to: extent) }
        if backgroundBlur > 0 {
            let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: backgroundBlur).cropped(to: extent)
            let middle = image.cropped(to: CGRect(x: 150, y: 190, width: 300, height: 370))
            image = middle.composited(over: blurred)
        }
        return CIContext().createCGImage(image, from: extent)!
    }

    static let middle = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

    @Test func sharpBeatsShaken() {
        let sharp = Sharpness.measure(Self.scene(), subject: Self.middle)
        let shaken = Sharpness.measure(Self.scene(blur: 3), subject: Self.middle)
        #expect(sharp > shaken * 3)
    }

    /// FR-002: a sharp subject on a blurred background is a sharp frame.
    @Test func backgroundBlurOnPurposeIsNotBlur() {
        let portrait = Sharpness.measure(Self.scene(backgroundBlur: 6), subject: Self.middle)
        let sharp = Sharpness.measure(Self.scene(), subject: Self.middle)
        #expect(portrait > sharp * 0.8)
    }

    @Test func choosesTheSharpestFrame() {
        let frames = [3.0, 0, 1.5].map { FrameQuality(sharpness: Sharpness.measure(Self.scene(blur: $0), subject: Self.middle)) }
        let pick = BurstSelector.choose(frames)!
        #expect(pick.index == 1 && pick.reason == .motionBlur && !pick.allBlurred)
    }

    @Test func allBlurredIsReported() {
        let frames = [8.0, 9, 10].map { FrameQuality(sharpness: Sharpness.measure(Self.scene(blur: $0), subject: Self.middle)) }
        let pick = BurstSelector.choose(frames)!
        #expect(pick.index == 0, "the least blurred")
        #expect(pick.allBlurred, "tell the user to hold the phone still (Hikâye 1.3)")
    }

    static let open = FaceEyes(left: 0.32, right: 0.30), closed = FaceEyes(left: 0.08, right: 0.1)

    /// Hikâye 2.1: a frame with closed eyes loses even when sharper.
    @Test func closedEyesLoseToOpenEyes() {
        let frames = [FrameQuality(sharpness: 0.01, faces: [Self.closed]), FrameQuality(sharpness: 0.006, faces: [Self.open])]
        let pick = BurstSelector.choose(frames)!
        #expect(pick.index == 1 && pick.reason == .eyesClosed)
    }

    /// Hikâye 2.2: nobody fully open → most open eyes.
    @Test func mostOpenEyesWhenNoFrameHasAll() {
        let frames = [FrameQuality(sharpness: 0.01, faces: [Self.closed, Self.closed]),
                      FrameQuality(sharpness: 0.005, faces: [Self.open, Self.closed]),
                      FrameQuality(sharpness: 0.009, faces: [Self.closed, Self.open])]
        #expect(BurstSelector.choose(frames)?.index == 2)
    }

    @Test func eyeOpennessFromOutline() {
        let openEye = [CGPoint(x: 0, y: 0.5), CGPoint(x: 0.3, y: 0.65), CGPoint(x: 0.7, y: 0.65), CGPoint(x: 1, y: 0.5),
                       CGPoint(x: 0.7, y: 0.35), CGPoint(x: 0.3, y: 0.35)]
        let shut = openEye.map { CGPoint(x: $0.x, y: 0.5 + ($0.y - 0.5) * 0.2) }
        #expect(FaceEyes.openness(openEye)! > FaceEyes.closedBelow)
        #expect(FaceEyes(left: FaceEyes.openness(shut), right: FaceEyes.openness(shut)).isClosed)
        #expect(!FaceEyes(left: nil, right: nil).isClosed, "no eyes seen is not closed eyes")
    }

    @Test func seriesOnlyWhenItHelps() {
        #expect(BurstPlan.frameCount(hasPerson: false, phoneRotation: 0.05, isDim: false, isConstrained: false) == 1, "still plate")
        #expect(BurstPlan.frameCount(hasPerson: true, phoneRotation: 0, isDim: false, isConstrained: false) == 3)
        #expect(BurstPlan.frameCount(hasPerson: false, phoneRotation: 0.8, isDim: false, isConstrained: false) == 3)
        #expect(BurstPlan.frameCount(hasPerson: false, phoneRotation: 0, isDim: true, isConstrained: false) == 3)
        #expect(BurstPlan.frameCount(hasPerson: true, phoneRotation: 1, isDim: true, isConstrained: true) == 1, "hot or low on memory")
    }

    @Test func singleFrameIsKept() {
        #expect(BurstSelector.choose([FrameQuality(sharpness: 0.01)])?.reason == .only)
        #expect(BurstSelector.choose([]) == nil)
    }
}
