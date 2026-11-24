import CoreGraphics
import Foundation

/// Finds the photo inside a social app screenshot (spec 05 FR-003, Hikâye 1.2), so the app's bars, names and
/// buttons do not reach the color statistics. Pure CoreGraphics; tested on macOS with drawn screenshots.
///
/// The app's interface sits on one flat background color (white or near-black). The photo is the tallest band of
/// rows that are mostly not that color; a row of pure background splits bands, so the profile row and the buttons
/// (mostly background with a little content) never join the photo. The band is snapped to the post shapes
/// Instagram uses (square, 4:5, 1.91:1) when it is close to one of them.
public enum ScreenshotCrop {
    /// Screens are tall; photos and their crops are not.
    static let minimumScreenAspect = 1.7
    static let width = 240

    /// The photo's region, normalized with the origin at the top left; nil when the image does not look like a
    /// screenshot or no clear photo band is found (then the whole image is used, Hikâye 2).
    public static func photoRegion(in image: CGImage) -> CGRect? {
        let aspect = Double(image.height) / Double(max(image.width, 1))
        guard aspect >= minimumScreenAspect else { return nil }
        let w = width, h = Int((Double(w) * aspect).rounded())
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return photoRegion(pixels: px, width: w, height: h)
    }

    // MARK: - On pixels (row 0 is the top)

    static func photoRegion(pixels px: [UInt8], width w: Int, height h: Int) -> CGRect? {
        guard let bg = background(px, w, h) else { return nil }
        func isBackground(_ i: Int) -> Bool {
            abs(Int(px[i]) - bg.0) + abs(Int(px[i + 1]) - bg.1) + abs(Int(px[i + 2]) - bg.2) <= 30
        }
        // Share of each row that is not background.
        var content = [Double](repeating: 0, count: h)
        for y in 0..<h {
            var n = 0
            for x in 0..<w where !isBackground((y * w + x) * 4) { n += 1 }
            content[y] = Double(n) / Double(w)
        }
        // Bands of rows separated by pure background rows; a band counts as photo when most of its rows are.
        var bands: [(start: Int, end: Int, photoRows: Int)] = []
        var start: Int?, photoRows = 0
        for y in 0...h {
            let pure = y == h || content[y] < 0.03
            if pure {
                if let s = start { bands.append((s, y, photoRows)) }
                start = nil; photoRows = 0
            } else {
                if start == nil { start = y }
                if content[y] >= 0.5 { photoRows += 1 }
            }
        }
        let photoBands = bands.filter { Double($0.photoRows) >= 0.6 * Double($0.end - $0.start) }
        guard let best = photoBands.max(by: { ($0.end - $0.start) < ($1.end - $1.start) }),
              Double(best.end - best.start) >= 0.2 * Double(h) else { return nil }

        // Columns inside the band: the photo may not span the whole width.
        var left = w, right = 0
        for x in 0..<w {
            var n = 0
            for y in best.start..<best.end where !isBackground((y * w + x) * 4) { n += 1 }
            if Double(n) >= 0.5 * Double(best.end - best.start) { left = min(left, x); right = max(right, x + 1) }
        }
        guard right > left else { return nil }
        var rect = CGRect(x: Double(left) / Double(w), y: Double(best.start) / Double(h),
                          width: Double(right - left) / Double(w), height: Double(best.end - best.start) / Double(h))
        rect = snapped(rect, screenAspect: Double(h) / Double(w))
        return rect
    }

    /// The interface color: the most common color of the top and bottom strips (status bar, tab bar).
    static func background(_ px: [UInt8], _ w: Int, _ h: Int) -> (Int, Int, Int)? {
        let strip = max(2, h / 25)
        var counts: [Int: Int] = [:]
        for y in Array(0..<strip) + Array((h - strip)..<h) {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let key = (Int(px[i]) / 8) << 10 | (Int(px[i + 1]) / 8) << 5 | (Int(px[i + 2]) / 8)
                counts[key, default: 0] += 1
            }
        }
        guard let (key, n) = counts.max(by: { $0.value < $1.value }), Double(n) >= 0.5 * Double(2 * strip * w) else { return nil }
        return ((key >> 10 & 31) * 8 + 4, (key >> 5 & 31) * 8 + 4, (key & 31) * 8 + 4)
    }

    /// Post shapes (height / width): 1.91:1, square, 4:5. Snapped only when within 6%, keeping the band's middle.
    static let postAspects = [1 / 1.91, 1.0, 1.25]

    static func snapped(_ r: CGRect, screenAspect: Double) -> CGRect {
        let aspect = (r.height * screenAspect) / r.width
        guard let target = postAspects.min(by: { abs($0 - aspect) < abs($1 - aspect) }),
              abs(target - aspect) / target <= 0.06 else { return r }
        let height = r.width * target / screenAspect
        return CGRect(x: r.minX, y: r.midY - height / 2, width: r.width, height: height)
    }

    /// The region as a crop rectangle in the image's pixels (CGImage origin is the top left too).
    public static func cropped(_ image: CGImage) -> CGImage? {
        guard let r = photoRegion(in: image) else { return nil }
        let rect = CGRect(x: r.minX * Double(image.width), y: r.minY * Double(image.height),
                          width: r.width * Double(image.width), height: r.height * Double(image.height)).integral
        return image.cropping(to: rect)
    }
}
