import CoreGraphics
import Foundation
import Testing
@testable import CaptureKit

@Suite("4:5 photo on a 9:16 Story (spec 07 Hikâye 1.3)")
struct StoryComposerTests {
    static func photo() -> CGImage {
        let ctx = CGContext(data: nil, width: 800, height: 1000, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 1000))
        return ctx.makeImage()!
    }

    static func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (Int, Int, Int) {
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (Int(px[0]), Int(px[1]), Int(px[2]))
    }

    @Test func storyIsNineBySixteenWithThePhotoInTheMiddle() throws {
        let story = try #require(StoryComposer.compose(Self.photo()))
        #expect(story.width == 1080 && story.height == 1920)
        let center = Self.pixel(story, 540, 960), original = Self.pixel(Self.photo(), 400, 500)
        #expect(abs(center.0 - original.0) < 4 && abs(center.1 - original.1) < 4 && abs(center.2 - original.2) < 4,
                "photo at full color in the middle: \(center) vs \(original)")
        // Above the photo: the blurred, dimmed photo, not black and not white.
        let top = Self.pixel(story, 540, 80)
        #expect(top.0 > 60 && top.0 < center.0, "background matches the photo: \(top)")
    }
}
