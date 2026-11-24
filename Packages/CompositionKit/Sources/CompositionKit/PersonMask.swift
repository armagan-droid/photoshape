import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// Where the people are in the example, on the color sample's grid (spec 05 FR-004). Apple Vision person
/// segmentation works on any still image, on the device (Constitution I, V). Nil without a usable mask.
public enum PersonMask {
    /// Row 0 is the top, values 0…1, `width × height` cells.
    public static func grid(for image: CGImage, width: Int, height: Int) -> [Float]? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        guard (try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])) != nil,
              let buffer = request.results?.first?.pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bw = CVPixelBufferGetWidth(buffer), bh = CVPixelBufferGetHeight(buffer), stride = CVPixelBufferGetBytesPerRow(buffer)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        return average(width: width, height: height) { x0, x1, y0, y1 in
            let sx0 = x0 * bw / width, sx1 = max(sx0 + 1, x1 * bw / width)
            let sy0 = y0 * bh / height, sy1 = max(sy0 + 1, y1 * bh / height)
            var sum = 0, n = 0
            for y in sy0..<min(sy1, bh) { for x in sx0..<min(sx1, bw) { sum += Int(bytes[y * stride + x]); n += 1 } }
            return n > 0 ? Float(sum) / Float(n * 255) : 0
        }
    }

    static func average(width: Int, height: Int, cell: (Int, Int, Int, Int) -> Float) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(width * height)
        for y in 0..<height { for x in 0..<width { out.append(cell(x, x + 1, y, y + 1)) } }
        return out
    }
}
