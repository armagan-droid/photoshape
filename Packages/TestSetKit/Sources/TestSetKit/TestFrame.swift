import CoreGraphics
import CoreVideo
import Foundation
import ImageIO

/// Fields read from the image file itself, never typed by hand (FR-005).
public struct FileMetadata: Sendable, Hashable {
    public var hasDepth: Bool
    public var device: String?
    public var lens: String?
    /// EXIF orientation of the stored pixels. Everything this package returns is already oriented.
    public var orientation: CGImagePropertyOrientation
    /// Displayed (oriented) size, the space region labels are expressed in.
    public var pixelWidth: Int
    public var pixelHeight: Int

    static func read(from url: URL) throws -> FileMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw TestSetError.unreadableImage(url.lastPathComponent)
        }
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let exifAux = props[kCGImagePropertyExifAuxDictionary] as? [CFString: Any]
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)
            .flatMap { CGImagePropertyOrientation(rawValue: $0.uint32Value) } ?? .up
        let rawWidth = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let rawHeight = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        return FileMetadata(
            hasDepth: DepthMap.auxiliaryInfo(source) != nil,
            device: tiff?[kCGImagePropertyTIFFModel] as? String,
            lens: (exif?[kCGImagePropertyExifLensModel] ?? exifAux?[kCGImagePropertyExifAuxLensModel]) as? String,
            orientation: orientation,
            pixelWidth: orientation.swapsAxes ? rawHeight : rawWidth,
            pixelHeight: orientation.swapsAxes ? rawWidth : rawHeight
        )
    }
}

/// Depth or disparity map as plain values, independent of AVFoundation (Constitution IV).
public struct DepthMap: Sendable, Hashable {
    public enum Kind: Sendable, Hashable { case disparity, depth }
    public let kind: Kind
    public let width: Int
    public let height: Int
    /// Row-major, `width * height` values. Disparity in 1/m, depth in m.
    public let values: [Float]

    static func auxiliaryInfo(_ source: CGImageSource) -> (Kind, [CFString: Any])? {
        if let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeDisparity)
            as? [CFString: Any] { return (.disparity, info) }
        if let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeDepth)
            as? [CFString: Any] { return (.depth, info) }
        return nil
    }

    static func read(from url: URL) throws -> DepthMap? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw TestSetError.unreadableImage(url.lastPathComponent)
        }
        guard let (kind, info) = auxiliaryInfo(source) else { return nil }
        guard let data = info[kCGImageAuxiliaryDataInfoData] as? Data,
              let desc = info[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any],
              let width = desc[kCGImagePropertyWidth] as? Int,
              let height = desc[kCGImagePropertyHeight] as? Int,
              let bytesPerRow = desc[kCGImagePropertyBytesPerRow] as? Int,
              let format = (desc[kCGImagePropertyPixelFormat] as? NSNumber)?.uint32Value else {
            throw TestSetError.unreadableDepth(url.lastPathComponent)
        }
        let isHalf: Bool
        switch format {
        case kCVPixelFormatType_DisparityFloat16, kCVPixelFormatType_DepthFloat16: isHalf = true
        case kCVPixelFormatType_DisparityFloat32, kCVPixelFormatType_DepthFloat32: isHalf = false
        default: throw TestSetError.unreadableDepth(url.lastPathComponent)
        }
        let bytesPerValue = isHalf ? 2 : 4
        guard bytesPerRow >= width * bytesPerValue, data.count >= bytesPerRow * height else {
            throw TestSetError.unreadableDepth(url.lastPathComponent)
        }
        var values = [Float](repeating: 0, count: width * height)
        data.withUnsafeBytes { raw in
            for y in 0..<height {
                let row = y * bytesPerRow
                for x in 0..<width {
                    let offset = row + x * bytesPerValue
                    values[y * width + x] = isHalf
                        ? Float(raw.loadUnaligned(fromByteOffset: offset, as: Float16.self))
                        : raw.loadUnaligned(fromByteOffset: offset, as: Float.self)
                }
            }
        }
        // The depth description carries its own orientation; fall back to the image's.
        let imageProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = (desc[kCGImagePropertyOrientation] ?? imageProps?[kCGImagePropertyOrientation]) as? NSNumber
        let orientation = rawOrientation.flatMap { CGImagePropertyOrientation(rawValue: $0.uint32Value) } ?? .up
        return DepthMap(kind: kind, width: width, height: height, values: values).oriented(orientation)
    }

    /// Applies an EXIF orientation so the map lines up with the displayed image.
    func oriented(_ orientation: CGImagePropertyOrientation) -> DepthMap {
        guard orientation != .up else { return self }
        let (w, h) = (width, height)
        let outW = orientation.swapsAxes ? h : w, outH = orientation.swapsAxes ? w : h
        var out = [Float](repeating: 0, count: values.count)
        for oy in 0..<outH {
            for ox in 0..<outW {
                // Source pixel shown at displayed position (ox, oy).
                let (sx, sy): (Int, Int)
                switch orientation {
                case .up: (sx, sy) = (ox, oy)
                case .upMirrored: (sx, sy) = (w - 1 - ox, oy)
                case .down: (sx, sy) = (w - 1 - ox, h - 1 - oy)
                case .downMirrored: (sx, sy) = (ox, h - 1 - oy)
                case .leftMirrored: (sx, sy) = (oy, ox)
                case .right: (sx, sy) = (oy, h - 1 - ox)
                case .rightMirrored: (sx, sy) = (w - 1 - oy, h - 1 - ox)
                case .left: (sx, sy) = (w - 1 - oy, ox)
                }
                out[oy * outW + ox] = values[sy * w + sx]
            }
        }
        return DepthMap(kind: kind, width: outW, height: outH, values: out)
    }
}

extension CGImagePropertyOrientation {
    var swapsAxes: Bool { [.left, .right, .leftMirrored, .rightMirrored].contains(self) }
}

/// One labeled frame of the test set. Image and depth are loaded on demand.
public struct TestFrame: Sendable, Hashable {
    public let id: String
    public let imageURL: URL
    public let labelURL: URL
    public let labels: FrameLabels
    public let metadata: FileMetadata

    /// Full-resolution image in displayed orientation (the space region labels use).
    public func loadImage() throws -> CGImage { try Self.loadOrientedImage(imageURL) }

    /// Displayed-orientation image, optionally downscaled so the long side is at most `maxPixelSize`.
    public static func loadOrientedImage(_ url: URL, maxPixelSize: Int? = nil) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw TestSetError.unreadableImage(url.lastPathComponent)
        }
        let longSide = max(props[kCGImagePropertyPixelWidth] as? Int ?? 0, props[kCGImagePropertyPixelHeight] as? Int ?? 0)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixelSize ?? longSide, longSide),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw TestSetError.unreadableImage(url.lastPathComponent)
        }
        return image
    }

    /// `nil` when the file carries no depth data. Oriented like `loadImage()`.
    public func loadDepth() throws -> DepthMap? { try DepthMap.read(from: imageURL) }
}

public enum TestSetError: Error, CustomStringConvertible {
    case notFound(String)
    case unreadableImage(String)
    case unreadableDepth(String)

    public var description: String {
        switch self {
        case .notFound(let hint): "test set not found: \(hint)"
        case .unreadableImage(let name): "cannot read image \(name)"
        case .unreadableDepth(let name): "cannot read depth data in \(name)"
        }
    }
}
