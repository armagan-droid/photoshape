import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CaptureKit

@Suite("4:5 rendering from the original capture (FR-002, FR-004, FR-006, SC-005)")
struct RendererTests {
    /// HEIC like a portrait iPhone capture: stored landscape (80×60), EXIF orientation 6, red marker in the
    /// stored top-left 8×8, GPS present (must be stripped).
    private func capture(width: Int = 80, height: Int = 60, orientation: Int = 6) throws -> Data {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: height - 8, width: 8, height: 8))
        let data = NSMutableData()
        let dest = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil)!
        let props: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "iPhone 12"],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 41.0, kCGImagePropertyGPSLatitudeRef: "N"],
        ]
        CGImageDestinationAddImage(dest, ctx.makeImage()!, props as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))
        return data as Data
    }

    private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (Int, Int, Int) {
        var b = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &b, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (Int(b[0]), Int(b[1]), Int(b[2]))
    }

    @Test func defaultRecordCropsTheDisplayedFrameToExactFourByFive() throws {
        let original = try capture()
        let size = try #require(EditedPhotoRenderer.orientedSize(of: original))
        #expect(size.width == 60 && size.height == 80)

        let record = EditRecord.default(appVersion: "test", orientedWidth: size.width, orientedHeight: size.height)
        let image = try EditedPhotoRenderer.render(original: original, record: record)
        #expect(image.width * 5 == image.height * 4)
        #expect(image.width == 60 && image.height == 75)
        // Stored top-left marker is shown top-right after the clockwise turn; the 4:5 crop trims 2–3 rows on top.
        let (r, g, _) = pixel(image, 57, 2)
        #expect(r > 200 && g < 80)
        let (r2, _, b2) = pixel(image, 2, 2)
        #expect(r2 < 120 && b2 > 150)
    }

    @Test func encodedOutputsAreUprightWithoutLocation() throws {
        let original = try capture()
        let size = try #require(EditedPhotoRenderer.orientedSize(of: original))
        let record = EditRecord.default(appVersion: "test", orientedWidth: size.width, orientedHeight: size.height)
        let image = try EditedPhotoRenderer.render(original: original, record: record)

        for (data, type) in [(try EditedPhotoRenderer.encode(image, as: .heic, metadataFrom: original), UTType.heic),
                             (try EditedPhotoRenderer.encode(image, as: .jpeg, metadataFrom: original), UTType.jpeg)] {
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            #expect(CGImageSourceGetType(source) as String? == type.identifier)
            let props = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            #expect(props[kCGImagePropertyGPSDictionary] == nil, "no location (FR-006)")
            #expect((props[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
            #expect(props[kCGImagePropertyPixelWidth] as? Int == 60)
            #expect(props[kCGImagePropertyPixelHeight] as? Int == 75)
            let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            #expect(tiff?[kCGImagePropertyTIFFModel] as? String == "iPhone 12", "camera metadata kept")
        }
    }

    @Test func stripLocationRemovesGPSFromTheOriginal() throws {
        let original = try capture()
        let stripped = try EditedPhotoRenderer.strippingLocation(from: original)
        let props = try #require(CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithData(stripped as CFData, nil)!, 0, nil) as? [CFString: Any])
        #expect(props[kCGImagePropertyGPSDictionary] == nil)
        #expect(props[kCGImagePropertyOrientation] as? Int == 6, "original keeps its orientation")
    }

    @Test func garbageInputThrows() {
        #expect(throws: (any Error).self) { try EditedPhotoRenderer.render(original: Data([1, 2, 3]), record: .default(appVersion: "", orientedWidth: 4, orientedHeight: 5)) }
    }
}

@Suite("Capture processing (after the shutter)")
struct CaptureProcessorTests {
    @Test func producesMatchingEditShareAndThumbnail() throws {
        let ctx = CGContext(data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        let data = NSMutableData()
        let dest = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 1.0]] as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))

        let p = try CaptureProcessor.process(original: data as Data, appVersion: "1.0 (1)", thumbnailLongSide: 100)
        func size(_ d: Data) -> (Int, Int) {
            let props = CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithData(d as CFData, nil)!, 0, nil) as! [CFString: Any]
            return (props[kCGImagePropertyPixelWidth] as! Int, props[kCGImagePropertyPixelHeight] as! Int)
        }
        #expect(size(p.edited) == (300, 375))
        #expect(p.editedType == .heic, "macOS can encode HEIC")
        #expect(size(p.shareJPEG) == (300, 375))
        #expect(p.thumbnail.width == 80 && p.thumbnail.height == 100)
        #expect(p.record.appVersion == "1.0 (1)")
        let origProps = CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithData(p.original as CFData, nil)!, 0, nil) as! [CFString: Any]
        #expect(origProps[kCGImagePropertyGPSDictionary] == nil)
    }
}

@Suite("Look applied during processing (spec 03 FR-005)")
struct LookProcessingTests {
    @Test func appliesTheGivenTransformAndRecordsTheLook() throws {
        let ctx = CGContext(data: nil, width: 400, height: 500, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 500))
        let data = NSMutableData()
        let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        #expect(CGImageDestinationFinalize(dest))

        let look = EditRecord.LookReference(id: "test", version: 1, strength: 1)
        let p = try CaptureProcessor.process(original: data as Data, appVersion: "t", look: look) { image in
            image.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0)]) // red → 0
        }
        #expect(p.record.look == look)
        let thumb = p.thumbnail
        var px = [UInt8](repeating: 0, count: 4)
        let c = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(thumb, in: CGRect(x: -thumb.width / 2, y: -thumb.height / 2, width: thumb.width, height: thumb.height))
        #expect(px[0] < 20 && px[1] > 100, "look transform was applied")
    }
}
