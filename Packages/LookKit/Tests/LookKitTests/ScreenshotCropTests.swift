import CoreGraphics
import Foundation
import Testing
@testable import LookKit

/// Spec 05 FR-003, SC-003 (synthetic part): drawn Instagram-like screenshots, light and dark, square, 4:5 and
/// wide posts, with a profile row, buttons, caption and carousel dots. Real screenshots come with the test set.
@Suite("Photo region in a screenshot (spec 05 FR-003, SC-003)")
struct ScreenshotCropTests {
    struct Layout {
        var dark = false
        /// Post height / width.
        var post: Double = 1
        var photoTop: Double = 0.2
        var carouselDots = false
        /// The photo has a bright, nearly white area (a plate) touching its top edge.
        var brightTop = false
        var moody = false
    }

    /// 1170 × 2532 (iPhone screen), drawn with the origin at the bottom left (CoreGraphics), so y is flipped.
    static func screenshot(_ l: Layout) -> (CGImage, CGRect) {
        let w = 390, h = 844
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let bg: CGFloat = l.dark ? 0 : 1, ink: CGFloat = l.dark ? 0.95 : 0.1
        func fill(_ r: CGRect, _ c: CGColor) { ctx.setFillColor(c); ctx.fill(CGRect(x: r.minX, y: CGFloat(h) - r.maxY, width: r.width, height: r.height)) }
        func gray(_ v: CGFloat) -> CGColor { CGColor(red: v, green: v, blue: v, alpha: 1) }
        fill(CGRect(x: 0, y: 0, width: w, height: h), gray(bg))
        // Status bar text, app bar, profile row (avatar + name).
        fill(CGRect(x: 30, y: 14, width: 40, height: 12), gray(ink)); fill(CGRect(x: 320, y: 14, width: 44, height: 12), gray(ink))
        fill(CGRect(x: 16, y: 60, width: 110, height: 22), gray(ink))
        let top = l.photoTop * Double(h)
        fill(CGRect(x: 12, y: top - 44, width: 34, height: 34), CGColor(red: 0.8, green: 0.4, blue: 0.3, alpha: 1))
        fill(CGRect(x: 54, y: top - 34, width: 90, height: 12), gray(ink))
        // The photo: full width, a warm gradient with texture.
        let ph = Double(w) * l.post
        var seed: UInt64 = 7
        func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1) }
        for row in stride(from: 0, to: Int(ph), by: 4) {
            for col in stride(from: 0, to: w, by: 6) {
                let t = CGFloat(row) / CGFloat(ph)
                var v = (l.moody ? 0.12 : 0.45) + 0.25 * t + 0.08 * rnd()
                if l.brightTop, row < Int(ph * 0.3), (col - w / 2) * (col - w / 2) < 140 * 140 { v = 0.93 + 0.04 * rnd() }
                fill(CGRect(x: Double(col), y: top + Double(row), width: 6, height: 4), CGColor(red: min(1, v + 0.1), green: v, blue: max(0, v - 0.12), alpha: 1))
            }
        }
        // Buttons, carousel dots, likes and caption, tab bar.
        let below = top + ph
        for i in 0..<3 { fill(CGRect(x: 14 + i * 40, y: Int(below) + 12, width: 26, height: 24), gray(ink)) }
        if l.carouselDots { for i in 0..<4 { fill(CGRect(x: 176 + i * 10, y: Int(below) + 20, width: 6, height: 6), gray(0.5)) } }
        fill(CGRect(x: 14, y: below + 50, width: 120, height: 12), gray(ink))
        fill(CGRect(x: 14, y: below + 70, width: 300, height: 12), gray(ink))
        for i in 0..<5 { fill(CGRect(x: 30 + i * 74, y: h - 50, width: 26, height: 26), gray(ink)) }
        // Truth, normalized top-left.
        let truth = CGRect(x: 0, y: top / Double(h), width: 1, height: ph / Double(h))
        return (ctx.makeImage()!, truth)
    }

    static func overlap(_ a: CGRect, _ b: CGRect) -> Double {
        let i = a.intersection(b)
        guard !i.isNull else { return 0 }
        return Double(i.width * i.height) / Double(a.union(b).width * a.union(b).height)
    }

    static let layouts: [Layout] = [
        Layout(), Layout(dark: true), Layout(post: 1.25), Layout(dark: true, post: 1.25),
        Layout(post: 1 / 1.91, photoTop: 0.3), Layout(dark: true, post: 1 / 1.91, photoTop: 0.25),
        Layout(carouselDots: true), Layout(dark: true, post: 1.25, carouselDots: true),
        Layout(brightTop: true), Layout(dark: true, moody: true), Layout(post: 1.25, photoTop: 0.12, brightTop: true),
    ]

    @Test(arguments: layouts.indices)
    func findsThePhoto(index: Int) throws {
        let (image, truth) = Self.screenshot(Self.layouts[index])
        let found = try #require(ScreenshotCrop.photoRegion(in: image))
        #expect(Self.overlap(found, truth) >= 0.95, "found \(found) truth \(truth)")
    }

    @Test func ordinaryPhotosAreLeftWhole() {
        let ctx = CGContext(data: nil, width: 400, height: 500, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 500))
        #expect(ScreenshotCrop.photoRegion(in: ctx.makeImage()!) == nil)
    }

    @Test func screenWithoutAPhotoIsLeftWhole() {
        // A settings-like screen: flat background and a few text lines.
        var l = Layout()
        l.post = 0.01
        let (image, _) = Self.screenshot(l)
        #expect(ScreenshotCrop.photoRegion(in: image) == nil)
    }

    @Test func croppedImageHasThePostShape() throws {
        let (image, _) = Self.screenshot(Layout(post: 1.25))
        let crop = try #require(ScreenshotCrop.cropped(image))
        #expect(abs(Double(crop.height) / Double(crop.width) - 1.25) < 0.03)
    }
}
