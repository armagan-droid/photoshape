import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Everything the app needs after the shutter: what to save, what to share and what to show.
public struct ProcessedCapture: @unchecked Sendable {
    /// Original capture (HEIC with depth when available), location removed. Saved as the Photos original.
    public let original: Data
    public let record: EditRecord
    /// Upright 4:5 edit, saved as the Photos edit. HEIC when the platform can encode it, otherwise JPEG.
    public let edited: Data
    public let editedType: UTType
    /// Upright 4:5 JPEG for the share sheet (widest compatibility).
    public let shareJPEG: Data
    /// Small upright 4:5 image for the corner preview.
    public let thumbnail: CGImage
}

public enum CaptureProcessor {
    /// - Parameters:
    ///   - look: what goes into the edit record; `applyLook` does the actual rendering on the upright 4:5 image.
    ///     CaptureKit does not know looks; the caller passes the renderer in (Constitution III).
    public static func process(original raw: Data, appVersion: String, look: EditRecord.LookReference? = nil,
                               applyLook: ((CIImage) -> CIImage)? = nil, thumbnailLongSide: Int = 300) throws -> ProcessedCapture {
        let original = try EditedPhotoRenderer.strippingLocation(from: raw)
        guard let size = EditedPhotoRenderer.orientedSize(of: original) else { throw EditedPhotoRenderer.Error.unreadable }
        let record = EditRecord.default(appVersion: appVersion, orientedWidth: size.width, orientedHeight: size.height, look: look)
        var edited = try EditedPhotoRenderer.render(original: original, record: record)
        if let applyLook {
            let input = CIImage(cgImage: edited)
            let space = edited.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
            guard let rendered = lookContext.createCGImage(applyLook(input), from: input.extent, format: .RGBA8, colorSpace: space) else {
                throw EditedPhotoRenderer.Error.encodingFailed
            }
            edited = rendered
        }
        // Some environments (e.g. the iOS simulator) cannot encode HEIC; the photo must not be lost over that.
        let (editedData, editedType): (Data, UTType)
        if let heic = try? EditedPhotoRenderer.encode(edited, as: .heic, metadataFrom: original) {
            (editedData, editedType) = (heic, .heic)
        } else {
            (editedData, editedType) = (try EditedPhotoRenderer.encode(edited, as: .jpeg, metadataFrom: original), .jpeg)
        }
        let jpeg = try EditedPhotoRenderer.encode(edited, as: .jpeg, metadataFrom: original, quality: 0.92)
        return ProcessedCapture(original: original, record: record, edited: editedData, editedType: editedType, shareJPEG: jpeg,
                                thumbnail: try thumbnail(of: jpeg, longSide: thumbnailLongSide))
    }

    private static let lookContext = CIContext(options: [.cacheIntermediates: false])

    static func thumbnail(of data: Data, longSide: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longSide,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw EditedPhotoRenderer.Error.unreadable
        }
        return image
    }
}
