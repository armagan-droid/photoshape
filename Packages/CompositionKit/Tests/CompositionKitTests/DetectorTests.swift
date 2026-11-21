import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import CompositionKit

@Suite("Vision subject detection (spec 04 FR-K1)")
struct DetectorTests {
    /// A dark cup on a light table, off center: the salient object is found in top-left coordinates.
    @Test func findsTheObjectInASimpleScene() throws {
        let w = 400, h = 500
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.93, green: 0.9, blue: 0.85, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 200, y: 260, width: 160, height: 160)) // CG origin bottom-left → upper right area
        ctx.setFillColor(CGColor(red: 0.35, green: 0.2, blue: 0.1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 225, y: 285, width: 110, height: 110))
        let subject = try #require(SubjectDetector.detect(in: ctx.makeImage()!), "Vision found nothing")
        #expect(subject.kind == .object)
        #expect(subject.box.midX > 0.5 && subject.box.midY < 0.5, "upper right, top-left origin: \(subject.box)")
    }
}
