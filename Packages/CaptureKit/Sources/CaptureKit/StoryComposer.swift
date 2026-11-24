import CoreGraphics
import CoreImage
import Foundation

/// A 4:5 photo placed on a 9:16 Story canvas (spec 07 Hikâye 1.3). The space around it is the same photo,
/// filled, blurred and dimmed, so the background always matches the photo (spec 07 açık soru 4, default).
public enum StoryComposer {
    public static let size = CGSize(width: 1080, height: 1920)
    /// Share of the canvas width the photo takes, with margins left for Instagram's own controls.
    static let photoWidth = 0.86

    public static func compose(_ photo: CGImage) -> CGImage? {
        let input = CIImage(cgImage: photo)
        let e = input.extent
        guard e.width > 0, e.height > 0 else { return nil }
        let canvas = CGRect(origin: .zero, size: size)

        // Background: fill the canvas, blur, dim.
        let fill = max(size.width / e.width, size.height / e.height)
        let filled = input.transformed(by: CGAffineTransform(scaleX: fill, y: fill))
        let fx = (filled.extent.width - size.width) / 2, fy = (filled.extent.height - size.height) / 2
        let background = filled.transformed(by: CGAffineTransform(translationX: -fx, y: -fy))
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 40)
            .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.12, kCIInputSaturationKey: 0.9])
            .cropped(to: canvas)

        // Foreground: the photo, centered.
        let fit = size.width * photoWidth / e.width
        let w = e.width * fit, h = e.height * fit
        let front = input.transformed(by: CGAffineTransform(scaleX: fit, y: fit)
            .concatenating(CGAffineTransform(translationX: (size.width - w) / 2, y: (size.height - h) / 2)))

        let space = photo.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        return CIContext(options: [.cacheIntermediates: false])
            .createCGImage(front.composited(over: background), from: canvas, format: .RGBA8, colorSpace: space)
    }
}
