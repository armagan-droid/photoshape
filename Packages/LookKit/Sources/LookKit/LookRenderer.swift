import CoreImage
import Foundation

/// Applies a look to an image. The live preview and the saved photo call the same function, only at
/// different sizes (FR-002); effects scale with image size so both look the same (SC-003).
public final class LookRenderer: @unchecked Sendable {
    public static let lutSize = 33
    /// Strength is quantized so preview and capture build the identical LUT (FR-003) and the cache stays small.
    public static let strengthStep = 0.01

    private let lock = NSLock()
    private var luts: [LookAdjustments: Data] = [:]
    private var order: [LookAdjustments] = []
    private let cacheLimit = 48
    private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    public init() {}

    /// - Parameters:
    ///   - effects: grain and vignette; turned off only by tests that measure the color transform alone.
    ///   - gains: white balance before the look (spec 02 Hikâye 3.2); applied in Core Image's linear working space.
    public func render(_ image: CIImage, recipe: LookRecipe, strength: Double, gains: ChannelGains = .neutral,
                       effects: Bool = true) -> CIImage {
        var out = image
        if !gains.isNeutral, let matrix = CIFilter(name: "CIColorMatrix") {
            let n = CGFloat(gains.norm)
            matrix.setValue(out, forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: CGFloat(gains.red) / n, y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0, y: 1 / n, z: 0, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: CGFloat(gains.blue) / n, w: 0), forKey: "inputBVector")
            if let result = matrix.outputImage { out = result.cropped(to: image.extent) }
        }
        let s = (min(1, max(0, strength)) / Self.strengthStep).rounded() * Self.strengthStep
        guard s > 0 else { return out }
        let a = recipe.adjustments.scaled(by: s)

        if a.hasPointwiseChange, let cube = CIFilter(name: "CIColorCubeWithColorSpace") {
            cube.setValue(out, forKey: kCIInputImageKey)
            cube.setValue(Self.lutSize, forKey: "inputCubeDimension")
            cube.setValue(lut(for: a), forKey: "inputCubeData")
            cube.setValue(sRGB, forKey: "inputColorSpace")
            if let result = cube.outputImage { out = result.cropped(to: image.extent) }
        }
        guard effects else { return out }
        if a.vignette > 0 { out = vignette(out, amount: a.vignette) }
        if a.grain > 0 { out = grain(out, amount: a.grain) }
        return out
    }

    public func lut(for adjustments: LookAdjustments) -> Data {
        lock.lock(); defer { lock.unlock() }
        if let cached = luts[adjustments] { return cached }
        let data = ColorTransform(adjustments).lutData(size: Self.lutSize)
        luts[adjustments] = data
        order.append(adjustments)
        if order.count > cacheLimit { luts[order.removeFirst()] = nil }
        return data
    }

    // MARK: - Effects (relative to image size)

    private func vignette(_ image: CIImage, amount: Double) -> CIImage {
        let e = image.extent
        guard let f = CIFilter(name: "CIVignetteEffect") else { return image }
        f.setValue(image, forKey: kCIInputImageKey)
        f.setValue(CIVector(x: e.midX, y: e.midY), forKey: kCIInputCenterKey)
        f.setValue(0.75 * hypot(e.width, e.height) / 2, forKey: kCIInputRadiusKey)
        f.setValue(amount * 0.9, forKey: kCIInputIntensityKey)
        f.setValue(0.6, forKey: "inputFalloff")
        return f.outputImage?.cropped(to: e) ?? image
    }

    /// Zero-mean monochrome grain. The pattern is fixed (deterministic) and scaled with the image,
    /// so it looks the same on a preview frame and on the full photo.
    private func grain(_ image: CIImage, amount: Double) -> CIImage {
        let e = image.extent
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return image }
        let scale = max(1, e.width / 1080)
        let gray = noise
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            ])
        let k = amount * 0.10
        let centered = gray.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: k, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: -k / 2, y: -k / 2, z: -k / 2, w: 0),
        ]).transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY)).cropped(to: e)
        return centered.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: image]).cropped(to: e)
    }
}
