import CoreGraphics
import CoreVideo
import Foundation
import ImageIO

/// Fields read from the image file itself, never typed by hand (FR-005).
public struct FileMetadata: Sendable, Hashable {
    public var hasDepth: Bool
    public var device: String?
    public var lens: String?
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
        return FileMetadata(
            hasDepth: DepthMap.auxiliaryInfo(source) != nil,
            device: tiff?[kCGImagePropertyTIFFModel] as? String,
            lens: (exif?[kCGImagePropertyExifLensModel] ?? exifAux?[kCGImagePropertyExifAuxLensModel]) as? String,
            pixelWidth: props[kCGImagePropertyPixelWidth] as? Int ?? 0,
            pixelHeight: props[kCGImagePropertyPixelHeight] as? Int ?? 0
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
        return DepthMap(kind: kind, width: width, height: height, values: values)
    }
}

/// One labeled frame of the test set. Image and depth are loaded on demand.
public struct TestFrame: Sendable, Hashable {
    public let id: String
    public let imageURL: URL
    public let labels: FrameLabels
    public let metadata: FileMetadata

    public func loadImage() throws -> CGImage {
        let options = [kCGImageSourceShouldCache: true] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
            throw TestSetError.unreadableImage(imageURL.lastPathComponent)
        }
        return image
    }

    /// `nil` when the file carries no depth data.
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
