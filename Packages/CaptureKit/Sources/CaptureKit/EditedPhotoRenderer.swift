import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Produces the edited (upright, 4:5) photo from the original capture data. Same code on device and in tests.
public enum EditedPhotoRenderer {
    public enum Error: Swift.Error { case unreadable, emptyCrop, encodingFailed }

    /// Upright size of the original (EXIF orientation applied).
    public static func orientedSize(of original: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(original as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let orientation = (props[kCGImagePropertyOrientation] as? Int) ?? 1
        return (5...8).contains(orientation) ? (h, w) : (w, h)
    }

    /// Applies `record` to the original: orientation, then the exact 4:5 crop.
    public static func render(original: Data, record: EditRecord) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(original as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw Error.unreadable
        }
        let longSide = max(props[kCGImagePropertyPixelWidth] as? Int ?? 0, props[kCGImagePropertyPixelHeight] as? Int ?? 0)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longSide,
        ]
        guard longSide > 0, let upright = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Error.unreadable
        }
        let crop = CropGeometry.snap(record.crop, width: upright.width, height: upright.height)
        guard crop.w > 0, crop.h > 0,
              let cropped = upright.cropping(to: CGRect(x: crop.x, y: crop.y, width: crop.w, height: crop.h)) else {
            throw Error.emptyCrop
        }
        return cropped
    }

    /// Encodes an upright rendered image. Camera metadata (EXIF, TIFF) is copied from the original;
    /// location and orientation are not (FR-006).
    public static func encode(_ image: CGImage, as type: UTType, metadataFrom original: Data?, quality: Double = 0.9) throws -> Data {
        var props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality, kCGImagePropertyOrientation: 1]
        if let original, let source = CGImageSourceCreateWithData(original as CFData, nil),
           let src = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            if var exif = src[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                exif[kCGImagePropertyExifPixelXDimension] = image.width
                exif[kCGImagePropertyExifPixelYDimension] = image.height
                props[kCGImagePropertyExifDictionary] = exif
            }
            if var tiff = src[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                tiff[kCGImagePropertyTIFFOrientation] = 1
                props[kCGImagePropertyTIFFDictionary] = tiff
            }
        }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw Error.encodingFailed
        }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw Error.encodingFailed }
        return data as Data
    }

    /// Returns the original unchanged when it has no location; otherwise a lossless copy without GPS.
    /// Our camera never adds location, so this is a safety net for FR-006.
    public static func strippingLocation(from original: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(original as CFData, nil),
              let type = CGImageSourceGetType(source) else { throw Error.unreadable }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        guard props?[kCGImagePropertyGPSDictionary] != nil else { return original }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, type, 1, nil) else { throw Error.encodingFailed }
        guard let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
              let mutable = CGImageMetadataCreateMutableCopy(metadata) else { throw Error.unreadable }
        var gpsPaths: [String] = []
        CGImageMetadataEnumerateTagsUsingBlock(metadata, nil, nil) { path, tag in
            let prefix = CGImageMetadataTagCopyPrefix(tag) as String? ?? ""
            let name = CGImageMetadataTagCopyName(tag) as String? ?? ""
            if prefix == "exif", name.hasPrefix("GPS") { gpsPaths.append(path as String) }
            return true
        }
        for path in gpsPaths { CGImageMetadataRemoveTagWithPath(mutable, nil, path as CFString) }
        let options: [CFString: Any] = [
            kCGImageDestinationMetadata: mutable,
            kCGImageDestinationMergeMetadata: false,
            kCGImageMetadataShouldExcludeGPS: true,
        ]
        guard CGImageDestinationCopyImageSource(dest, source, options as CFDictionary, nil) else {
            throw Error.encodingFailed
        }
        return data as Data
    }
}
