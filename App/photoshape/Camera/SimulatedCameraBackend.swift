#if targetEnvironment(simulator)
import AVFoundation
import CaptureKit
import UIKit
import UniformTypeIdentifiers

/// Stand-in camera for the simulator, which has none. Produces a generated scene stored like a real
/// portrait capture (landscape pixels + EXIF orientation 6), so cropping, saving, sharing and the
/// Photos edit record run end to end. Never part of a device build.
final class SimulatedCameraBackend: CameraBackend, @unchecked Sendable {
    private let still: CIImage?
    private let captureData: Data?

    init() {
        let upright = Self.drawScene(width: 1512, height: 2016)
        still = upright.map { CIImage(cgImage: $0) }
        captureData = upright.flatMap(Self.encodeAsSensorCapture)
    }

    func latestPreviewImage() -> CIImage? { still }

    func requestAccess() async -> Bool {
        // UI tests use this to reach the permission-denied screen.
        !UserDefaults.standard.bool(forKey: "SimulateCameraDenied")
    }

    func start() async -> [LensOption] {
        // Behaves like an iPhone 12: ultra wide + wide, digital "close".
        LensCatalog.options(for: .init(hasUltraWide: true, hasTelephoto: false, switchOverZoomFactors: [2], maxZoomFactor: 10))
    }

    func stop() async {}
    func setExposureBias(_ stops: Double) async {}
    func isLowLight() async -> Bool { false }
    func currentExposure() async -> LiveExposure? { nil }
    func setMeteringPoint(_ point: CGPoint) async {}
    func select(_ lens: LensOption) async {}
    func focus(atDevicePoint point: CGPoint) async {}

    func capturePhoto() async throws -> Data {
        try await Task.sleep(for: .milliseconds(120))
        guard let captureData else { throw CameraError.unavailable }
        return captureData
    }

    // MARK: - Scene

    private static func drawScene(width: Int, height: Int) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            let c = ctx.cgContext
            let colors = [UIColor(red: 0.93, green: 0.84, blue: 0.70, alpha: 1).cgColor,
                          UIColor(red: 0.45, green: 0.30, blue: 0.20, alpha: 1).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
            c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
            // A "cup" in the middle and markers in each corner make crop and orientation visible.
            UIColor.white.setFill()
            c.fillEllipse(in: CGRect(x: width / 2 - 350, y: height / 2 - 350, width: 700, height: 700))
            UIColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: width / 2 - 270, y: height / 2 - 270, width: 540, height: 540))
            for (i, color) in [UIColor.red, .green, .blue, .yellow].enumerated() {
                color.setFill()
                let x = i % 2 == 0 ? 0 : width - 120, y = i < 2 ? 0 : height - 120
                c.fill(CGRect(x: x, y: y, width: 120, height: 120))
            }
        }
        return image.cgImage
    }

    /// Rotates the upright scene into sensor (landscape) pixels and tags it with orientation 6, like a real capture.
    private static func encodeAsSensorCapture(_ upright: CGImage) -> Data? {
        let w = upright.height, h = upright.width
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Sensor pixels are the upright image turned 90° counter-clockwise.
        ctx.translateBy(x: CGFloat(w), y: 0)
        ctx.rotate(by: .pi / 2)
        ctx.draw(upright, in: CGRect(x: 0, y: 0, width: upright.width, height: upright.height))
        guard let sensor = ctx.makeImage() else { return nil }
        for type in [UTType.heic, .jpeg] {
            let data = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { continue }
            let props: [CFString: Any] = [
                kCGImagePropertyOrientation: 6,
                kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "Simulator"],
            ]
            CGImageDestinationAddImage(dest, sensor, props as CFDictionary)
            if CGImageDestinationFinalize(dest) { return data as Data }
        }
        return nil
    }
}
#endif
