import CoreGraphics
import Foundation
import ImageIO
import LookKit
import Testing
import UniformTypeIdentifiers
@testable import CompositionKit

@Suite("Example settings from the photo's data (spec 05 Hikâye 8, FR-018…FR-021, SC-014…SC-017)")
struct SettingsTests {
    static var exif: [String: Any] { [
        kCGImagePropertyExifExposureTime as String: 1.0 / 125,
        kCGImagePropertyExifFNumber as String: 1.78,
        kCGImagePropertyExifISOSpeedRatings as String: [64],
        kCGImagePropertyExifFocalLength as String: 6.86,
        kCGImagePropertyExifFocalLenIn35mmFilm as String: 24,
        kCGImagePropertyExifExposureBiasValue as String: -0.7,
        kCGImagePropertyExifFlash as String: 16, // off, did not fire
    ] }
    static var tiff: [String: Any] { [kCGImagePropertyTIFFModel as String: "iPhone 15 Pro", kCGImagePropertyTIFFMake as String: "Apple"] }
    static var gps: [String: Any] { [kCGImagePropertyGPSLatitude as String: 41.0, kCGImagePropertyGPSLongitude as String: 29.0] }

    /// Writes a small image with the given metadata, then reads its properties back like the app does.
    static func roundTrip(type: UTType, metadata: [String: Any]) throws -> [String: Any] {
        let ctx = CGContext(data: nil, width: 64, height: 80, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.6, green: 0.5, blue: 0.4, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 80))
        let data = NSMutableData()
        let dest = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, ctx.makeImage()!, metadata as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))
        let source = try #require(CGImageSourceCreateWithData(data, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
    }

    /// SC-014: JPEG and HEIC files with known values read back exactly; location is never part of the result.
    @Test(arguments: [UTType.jpeg, UTType.heic])
    func readsShootingValues(type: UTType) throws {
        let props = try Self.roundTrip(type: type, metadata: [
            kCGImagePropertyExifDictionary as String: Self.exif,
            kCGImagePropertyTIFFDictionary as String: Self.tiff,
            kCGImagePropertyGPSDictionary as String: Self.gps,
        ])
        let s = try #require(ExampleSettings(properties: props))
        #expect(abs((s.exposureTime ?? 0) - 1.0 / 125) < 1e-6)
        #expect(abs((s.fNumber ?? 0) - 1.78) < 0.01)
        #expect(s.iso == 64)
        #expect(s.focalLength35 == 24)
        #expect(abs((s.exposureBias ?? 0) + 0.7) < 0.01)
        #expect(s.flashFired == false)
        #expect(s.cameraModel == "iPhone 15 Pro")
        // FR-019: nothing else is kept.
        let encoded = String(decoding: try JSONEncoder().encode(s), as: UTF8.self)
        #expect(!encoded.contains("41") && !encoded.lowercased().contains("gps"))
    }

    @Test func screenshotsHaveNoSettings() throws {
        let props = try Self.roundTrip(type: .png, metadata: [
            kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifUserComment as String: "Screenshot"],
        ])
        #expect(ExampleSettings(properties: props) == nil)
        #expect(ExampleSettings(properties: [:]) == nil)
    }

    @Test func explanations() {
        #expect(ExampleSettings(exposureTime: 1.0 / 1000).shutterExplanation == "settings.explain.shutter.frozen")
        #expect(ExampleSettings(exposureTime: 1.0 / 125).shutterExplanation == "settings.explain.shutter.handheld")
        #expect(ExampleSettings(exposureTime: 1.0 / 15).shutterExplanation == "settings.explain.shutter.slow")
        #expect(ExampleSettings(exposureTime: 2).shutterExplanation == "settings.explain.shutter.long")
        // A phone's f/1.8 does not blur the background like a camera's f/1.8.
        #expect(ExampleSettings(fNumber: 1.8, focalLength: 6.9).apertureExplanation == "settings.explain.aperture.phone")
        #expect(ExampleSettings(fNumber: 1.8, focalLength: 50).apertureExplanation == "settings.explain.aperture.wide")
        #expect(ExampleSettings(fNumber: 11, focalLength: 35).apertureExplanation == "settings.explain.aperture.deep")
        #expect(ExampleSettings(iso: 3200).isoExplanation == "settings.explain.iso.high")
        #expect(ExampleSettings(focalLength35: 13).lensKey == "settings.lens.wide")
        #expect(ExampleSettings(focalLength35: 26).lensKey == "settings.lens.normal")
        #expect(ExampleSettings(focalLength35: 77).lensKey == "settings.lens.close")
        #expect(ExampleSettings.shutterText(1.0 / 125) == "1/125")
        #expect(ExampleSettings.shutterText(1.0 / 8) == "1/8")
        #expect(ExampleSettings.shutterText(2) == "2")
    }

    // MARK: - Read from the image

    static func stats(_ image: CGImage) throws -> ColorStats {
        ColorStats(colors: try #require(SceneSample(image: image)).colors)
    }

    static func tinted(_ temperature: Double) throws -> ColorStats {
        var recipe = LookRecipe.natural
        recipe.adjustments.temperature = temperature
        return try stats(ReadingTests.render(ReadingTests.neutralScene(), recipe))
    }

    @Test func neutralGrayReadsDaylightWhite() throws {
        #expect(abs(ExampleMeasurements.correlatedColorTemperature(a: 0, b: 0) - 6504) < 30)
        #expect(ExampleMeasurements.correlatedColorTemperature(a: 0, b: 20) < 5000, "yellowish gray = warm light")
        #expect(ExampleMeasurements.correlatedColorTemperature(a: 5, b: 40) < 3800, "strongly yellow = lamp")
        #expect(ExampleMeasurements.correlatedColorTemperature(a: 0, b: -10) > 8000)
    }

    /// SC-016 (synthetic): warmer look, lower temperature; cooler look, higher, step by step.
    @Test func temperatureMovesOneWay() throws {
        let temps = try [-0.8, -0.4, 0, 0.4, 0.8].map { try #require(ExampleMeasurements(stats: try Self.tinted($0)).colorTemperature) }
        for (a, b) in zip(temps, temps.dropFirst()) { #expect(a > b, "\(temps)") }
    }

    @Test func brightnessAndContrast() throws {
        let neutral = ExampleMeasurements(stats: try Self.stats(ReadingTests.neutralScene()))
        var bright = LookRecipe.natural; bright.adjustments.exposure = 0.8
        var dark = LookRecipe.natural; dark.adjustments.exposure = -0.8
        let up = ExampleMeasurements(stats: try Self.stats(ReadingTests.render(ReadingTests.neutralScene(), bright)))
        let down = ExampleMeasurements(stats: try Self.stats(ReadingTests.render(ReadingTests.neutralScene(), dark)))
        #expect(up.brightnessEV > neutral.brightnessEV && neutral.brightnessEV > down.brightnessEV)
        #expect((up.brightnessEV * 3).rounded() == up.brightnessEV * 3, "rounded to thirds")
        #expect(neutral.contrastStops > 2 && neutral.contrastStops < 10)
        #expect(neutral.highlightClip != nil && neutral.shadowClip != nil)
    }

    @Test func clippingIsCounted() throws {
        let ctx = Drawn.context(width: 100, height: 100, gray: 0.5)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 30))
        let m = ExampleMeasurements(stats: try Self.stats(ctx.makeImage()!))
        #expect((m.highlightClip ?? 0) > 0.2)
        #expect(m.highlightKey == "settings.explain.highlights.blown")
        #expect((m.shadowClip ?? 1) < 0.01)
    }

    /// SC-017: the card's sentences and the numbers never disagree.
    @Test func sentencesAndNumbersAgree() throws {
        var images = [ReadingTests.neutralScene()]
        for look in try LookCatalog.bundled().looks { images.append(ReadingTests.render(ReadingTests.neutralScene(), look)) }
        for t in [-0.8, 0.8] { var r = LookRecipe.natural; r.adjustments.temperature = t; images.append(ReadingTests.render(ReadingTests.neutralScene(), r)) }
        for e in [-1.2, 1.2] { var r = LookRecipe.natural; r.adjustments.exposure = e; images.append(ReadingTests.render(ReadingTests.neutralScene(), r)) }
        for image in images {
            let stats = try Self.stats(image)
            let m = ExampleMeasurements(stats: stats)
            let brightness = ExampleReading.brightness(stats)
            if brightness == "bright" { #expect(m.brightnessEV >= 0) }
            if brightness == "dark" { #expect(m.brightnessEV <= 0) }
            let color = ExampleReading.color(stats)
            if let k = m.colorTemperature {
                if color.hasPrefix("warm") { #expect(k < 6504, "\(color) at \(k) K") }
                if color.hasPrefix("cool") { #expect(k > 6504, "\(color) at \(k) K") }
            }
        }
    }

    /// Old saved profiles (before 2026-11-23) still give what can be computed (FR-023).
    @Test func oldProfilesGiveWhatTheyCan() throws {
        var stats = try Self.stats(ReadingTests.neutralScene())
        stats.neutralA = nil; stats.neutralB = nil; stats.highlightClip = nil; stats.shadowClip = nil
        let m = ExampleMeasurements(stats: stats)
        #expect(m.colorTemperature == nil && m.highlightClip == nil && m.temperatureKey == nil)
        #expect(m.contrastStops > 0)
    }
}
