import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import LookKit

/// Test images and pixel access.
enum Fixture {
    static let context = CIContext(options: [.cacheIntermediates: false])
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Cafe-like synthetic scene: warm gradient, a white "cup", colored patches.
    static func scene(width: Int = 800, height: Int = 1000) -> CIImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let colors = [CGColor(red: 0.92, green: 0.83, blue: 0.70, alpha: 1), CGColor(red: 0.35, green: 0.22, blue: 0.14, alpha: 1)] as CFArray
        ctx.drawLinearGradient(CGGradient(colorsSpace: sRGB, colors: colors, locations: [0, 1])!,
                               start: CGPoint(x: 0, y: height), end: .zero, options: [])
        ctx.setFillColor(CGColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: width / 4, y: height / 3, width: width / 2, height: width / 2))
        for (i, c) in [(0.8, 0.2, 0.15), (0.2, 0.6, 0.25), (0.2, 0.35, 0.8), (0.9, 0.75, 0.2)].enumerated() {
            ctx.setFillColor(CGColor(red: c.0, green: c.1, blue: c.2, alpha: 1))
            ctx.fill(CGRect(x: 20 + i * (width / 4), y: 20, width: width / 5, height: height / 8))
        }
        return CIImage(cgImage: ctx.makeImage()!)
    }

    /// Row 0: gray ramp 0→1. Row 1: hue ramp at saturation 0.8, value 0.8.
    static func ramps(width: Int = 1024) -> CIImage {
        var pixels = [UInt8](repeating: 255, count: width * 2 * 4)
        for x in 0..<width {
            let t = Double(x) / Double(width - 1)
            let v = UInt8((t * 255).rounded())
            pixels.replaceSubrange(x * 4..<x * 4 + 3, with: [v, v, v])
            let (r, g, b) = hsvToRGB(t, 0.8, 0.8)
            let o = (width + x) * 4
            pixels.replaceSubrange(o..<o + 3, with: [UInt8(r * 255), UInt8(g * 255), UInt8(b * 255)])
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: width, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: sRGB,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                            decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return CIImage(cgImage: image)
    }

    static func rgba8(_ image: CIImage) -> (width: Int, height: Int, data: [UInt8]) {
        let e = image.extent.integral
        let w = Int(e.width), h = Int(e.height)
        var data = [UInt8](repeating: 0, count: w * h * 4)
        context.render(image, toBitmap: &data, rowBytes: w * 4, bounds: e, format: .RGBA8, colorSpace: sRGB)
        return (w, h, data)
    }

    static func downscaled(_ image: CIImage, to width: Int) -> CIImage {
        let scale = Double(width) / image.extent.width
        let f = CIFilter(name: "CILanczosScaleTransform")!
        f.setValue(image, forKey: kCIInputImageKey)
        f.setValue(scale, forKey: kCIInputScaleKey)
        f.setValue(1.0, forKey: kCIInputAspectRatioKey)
        let out = f.outputImage!
        return out.cropped(to: CGRect(x: out.extent.minX, y: out.extent.minY,
                                      width: Double(width), height: (image.extent.height * scale).rounded(.down)))
    }

    static func meanDeltaE(_ a: CIImage, _ b: CIImage) -> Double {
        let pa = rgba8(a), pb = rgba8(b)
        let w = min(pa.width, pb.width), h = min(pa.height, pb.height)
        var total = 0.0
        for y in 0..<h { for x in 0..<w {
            let ia = (y * pa.width + x) * 4, ib = (y * pb.width + x) * 4
            func lab(_ d: [UInt8], _ i: Int) -> Lab { ColorScience.lab(fromSRGB: (Double(d[i]) / 255, Double(d[i + 1]) / 255, Double(d[i + 2]) / 255)) }
            total += ColorScience.deltaE2000(lab(pa.data, ia), lab(pb.data, ib))
        } }
        return total / Double(w * h)
    }
}

@Suite("Color transform and renderer (FR-002, FR-003, SC-001…SC-003)")
struct RenderTests {
    static let bundled = try! LookCatalog.bundled().looks

    @Test func identityWhenAllZero() {
        let t = ColorTransform(.zero)
        for v in stride(from: 0.0, through: 1.0, by: 0.1) {
            let (r, g, b) = t.apply(v, 1 - v, v * 0.5)
            #expect(abs(r - v) < 1e-9 && abs(g - (1 - v)) < 1e-9 && abs(b - v * 0.5) < 1e-9)
        }
    }

    @Test func eachAdjustmentMovesTheRightWay() {
        func gray(_ a: LookAdjustments, _ v: Double = 0.5) -> (Double, Double, Double) { ColorTransform(a).apply(v, v, v) }
        var a = LookAdjustments.zero
        a.exposure = 0.5; #expect(gray(a).0 > 0.5)
        a = .zero; a.temperature = 0.5; let warm = gray(a); #expect(warm.0 > warm.2)
        a = .zero; a.tint = 0.5; let magenta = gray(a); #expect(magenta.1 < magenta.0)
        a = .zero; a.contrast = 0.5; #expect(gray(a, 0.3).0 < 0.3 && gray(a, 0.7).0 > 0.7)
        a = .zero; a.shadows = 0.8; #expect(gray(a, 0.2).0 > 0.2)
        a = .zero; a.highlights = -0.8; #expect(gray(a, 0.8).0 < 0.8)
        a = .zero; a.fade = 0.8; #expect(gray(a, 0).0 > 0.05)
        a = .zero; a.saturation = -1; let mono = ColorTransform(a).apply(0.8, 0.3, 0.2); #expect(abs(mono.0 - mono.2) < 0.01)
        a = .zero; a.ranges[.orange] = .init(hue: 0, saturation: -1, luminance: 0)
        let orange = ColorTransform(a).apply(0.9, 0.55, 0.2), blue = ColorTransform(a).apply(0.2, 0.35, 0.8)
        #expect(orange.0 - orange.2 < 0.3, "orange desaturated")
        #expect(abs(blue.0 - 0.2) < 1e-6 && abs(blue.2 - 0.8) < 1e-6, "blue untouched")
    }

    @Test func outputStaysInRangeForExtremeRecipes() {
        var a = LookAdjustments.zero
        a.exposure = 1; a.contrast = 1; a.shadows = 1; a.highlights = 1; a.saturation = 1; a.vibrance = 1; a.temperature = 1; a.tint = -1
        for v in stride(from: 0.0, through: 1.0, by: 0.05) {
            let (r, g, b) = ColorTransform(a).apply(v, v * 0.3, 1 - v)
            #expect((0...1).contains(r) && (0...1).contains(g) && (0...1).contains(b))
        }
    }

    @Test func strengthZeroIsPixelIdentical() {
        let input = Fixture.scene(width: 200, height: 250)
        let renderer = LookRenderer()
        for recipe in Self.bundled {
            let out = renderer.render(input, recipe: recipe, strength: 0)
            #expect(Fixture.rgba8(out).data == Fixture.rgba8(input).data, "\(recipe.id)")
        }
        #expect(Fixture.rgba8(renderer.render(input, recipe: .natural, strength: 1)).data == Fixture.rgba8(input).data)
    }

    @Test func renderingIsDeterministic() {
        let input = Fixture.scene(width: 200, height: 250)
        for recipe in Self.bundled {
            let a = Fixture.rgba8(LookRenderer().render(input, recipe: recipe, strength: 0.7)).data
            let b = Fixture.rgba8(LookRenderer().render(input, recipe: recipe, strength: 0.7)).data
            #expect(a == b, "\(recipe.id)")
        }
    }

    @Test func everyLookActuallyChangesTheImage() {
        let input = Fixture.scene(width: 200, height: 250)
        for recipe in Self.bundled {
            #expect(Fixture.meanDeltaE(input, LookRenderer().render(input, recipe: recipe, strength: 1)) > 3, "\(recipe.id)")
        }
    }

    /// SC-001: on smooth 1024-px ramps no adjacent-pixel step exceeds 4/255 (no banding, no color breaks).
    @Test func noBandingOnRamps() {
        let ramps = Fixture.ramps()
        for recipe in Self.bundled {
            let p = Fixture.rgba8(LookRenderer().render(ramps, recipe: recipe, strength: 1, effects: false))
            var worst = 0
            for row in 0..<2 { for x in 1..<p.width { for c in 0..<3 {
                let i = (row * p.width + x) * 4 + c
                worst = max(worst, abs(Int(p.data[i]) - Int(p.data[i - 4])))
            } } }
            #expect(worst <= 4, "\(recipe.id): step \(worst)")
        }
    }

    /// SC-003: preview path (downscale, then render) matches capture path (render, then downscale).
    @Test func previewAndCapturePathsMatch() {
        let full = Fixture.scene(width: 1200, height: 1500)
        let renderer = LookRenderer()
        for recipe in Self.bundled {
            let capture = Fixture.downscaled(renderer.render(full, recipe: recipe, strength: 1), to: 300)
            let preview = renderer.render(Fixture.downscaled(full, to: 300), recipe: recipe, strength: 1)
            let dE = Fixture.meanDeltaE(capture, preview)
            #expect(dE <= 2, "\(recipe.id): mean ΔE2000 \(dE)")
        }
    }
}

@Suite("Catalog and licenses (FR-004, FR-009)")
struct CatalogTests {
    @Test func bundledCatalogHasFiveLooksAfterNatural() throws {
        let catalog = try LookCatalog.bundled()
        #expect(catalog.rejected.isEmpty, "\(catalog.rejected)")
        #expect(catalog.looks.count == 5)
        #expect(catalog.strip.first?.id == "natural")
        #expect(catalog.strip.count == 6)
        #expect(Set(catalog.looks.map(\.id)).count == 5)
        for look in catalog.looks {
            #expect(look.category == "cafe_food" && look.source == .bundled)
            #expect(!look.name.tr.isEmpty && !look.name.en.isEmpty)
        }
    }

    @Test func everySampleImageExistsAndIsLicensed() throws {
        let catalog = try LookCatalog.bundled()
        for look in catalog.looks {
            let sample = try #require(look.sample, "\(look.id) has no sample")
            #expect(catalog.sampleURL(for: look) != nil, "\(look.id): missing \(sample.image)")
            #expect(!sample.license.source.isEmpty && !sample.license.type.isEmpty && !sample.license.date.isEmpty, "\(look.id)")
        }
    }

    /// FR-009: the bundled folder passes the check; an unlicensed image or a placeholder in a release does not.
    @Test func licenseCheck() throws {
        let bundled = try #require(Bundle.module.url(forResource: "Looks", withExtension: nil))
        #expect(LicenseCheck.problems(in: bundled, release: false) == [])
        #expect(LicenseCheck.problems(in: bundled, release: true).count == 5, "placeholders cannot ship")

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data([0xFF, 0xD8]).write(to: dir.appendingPathComponent("stray.jpg"))
        #expect(LicenseCheck.problems(in: dir, release: false).contains { $0.hasPrefix("stray.jpg") })
    }

    @Test func brokenFilesAreSkippedNotFatal() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(RecipeTests.minimal.utf8).write(to: dir.appendingPathComponent("01-ok.look.json"))
        try Data("{ nope".utf8).write(to: dir.appendingPathComponent("02-broken.look.json"))
        let catalog = LookCatalog(directory: dir)
        #expect(catalog.looks.map(\.id) == ["test-look"])
        #expect(catalog.rejected.count == 1)
    }
}
