import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Builds throwaway test sets on disk. Fixtures are generated at run time so no binaries live in the repo.
struct FixtureSet {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestSetKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    /// A valid label dictionary; override fields per test.
    static func labels(id: String, _ overrides: [String: Any?] = [:]) -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "category": "cafe_food",
            "scene_type": "drink_closeup",
            "light": ["window_daylight"],
            "exposure": "good",
            "white_balance": "neutral",
            "highlights_clipped": false,
            "sharpness": "sharp",
            "composition": "good",
            "people_visible": "none",
        ]
        for (key, value) in overrides {
            if let value { dict[key] = value } else { dict.removeValue(forKey: key) }
        }
        return dict
    }

    @discardableResult
    func addImage(_ name: String, subdirectory: String? = nil, depth: Bool = false,
                  model: String? = "iPhone 12", lens: String? = "iPhone 12 back camera 4.2mm f/1.6") throws -> URL {
        let dir = subdirectory.map { root.appendingPathComponent($0, isDirectory: true) } ?? root
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = (name as NSString).pathExtension.lowercased()
        let type: UTType = (ext == "heic" || ext == "heif") ? .heic : (ext == "png" ? .png : .jpeg)
        let url = dir.appendingPathComponent(name)
        try Self.writeImage(to: url, type: type, depth: depth, model: model, lens: lens)
        return url
    }

    func addLabels(_ dict: [String: Any], named name: String, subdirectory: String? = nil) throws {
        let dir = subdirectory.map { root.appendingPathComponent($0, isDirectory: true) } ?? root
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: dir.appendingPathComponent(name))
    }

    func addRaw(_ text: String, named name: String) throws {
        try Data(text.utf8).write(to: root.appendingPathComponent(name))
    }

    /// Image + matching valid label file.
    func addFrame(_ stem: String, ext: String = "heic", depth: Bool = false, _ overrides: [String: Any?] = [:]) throws {
        try addImage("\(stem).\(ext)", depth: depth)
        try addLabels(Self.labels(id: stem, overrides), named: "\(stem).json")
    }

    // MARK: - Image writing

    static func writeImage(to url: URL, type: UTType, depth: Bool, model: String?, lens: String?) throws {
        let width = 64, height = 80
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw FixtureError.context
        }
        ctx.setFillColor(CGColor(red: 0.8, green: 0.6, blue: 0.4, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw FixtureError.destination
        }
        var props: [CFString: Any] = [:]
        if let model { props[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFModel: model] }
        if let lens { props[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifLensModel: lens] }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        if depth {
            let dw = 16, dh = 20
            var values = [Float32](repeating: 0, count: dw * dh)
            for i in values.indices { values[i] = Float32(i % dw) / Float32(dw) + 0.5 }
            let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
            let description: [CFString: Any] = [
                kCGImagePropertyWidth: dw,
                kCGImagePropertyHeight: dh,
                kCGImagePropertyBytesPerRow: dw * MemoryLayout<Float32>.size,
                kCGImagePropertyPixelFormat: kCVPixelFormatType_DisparityFloat32,
            ]
            let info: [CFString: Any] = [
                kCGImageAuxiliaryDataInfoData: data,
                kCGImageAuxiliaryDataInfoDataDescription: description,
            ]
            CGImageDestinationAddAuxiliaryDataInfo(dest, kCGImageAuxiliaryDataTypeDisparity, info as CFDictionary)
        }
        guard CGImageDestinationFinalize(dest) else { throw FixtureError.finalize }
    }

    enum FixtureError: Error { case context, destination, finalize }
}
