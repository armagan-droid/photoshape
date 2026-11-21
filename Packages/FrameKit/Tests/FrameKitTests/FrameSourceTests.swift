import CoreVideo
import Testing
@testable import FrameKit

@Suite("FrameSource boundary")
struct FrameSourceTests {
    private func buffer() throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, 8, 10, kCVPixelFormatType_32BGRA, nil, &pb)
        try #require(status == kCVReturnSuccess)
        return try #require(pb)
    }

    @Test func recordedSourceReplaysInOrderAndFinishes() async throws {
        let frames = try (0..<5).map { Frame(timestamp: Double($0) / 30, pixelBuffer: try buffer(), orientation: .right) }
        let source = RecordedFrameSource(frames)
        var seen: [Double] = []
        for await frame in source.frames() { seen.append(frame.timestamp) }
        #expect(seen == frames.map(\.timestamp))
    }

    @Test func framesCarryOptionalDepthAndMotion() throws {
        let motion = MotionSample(gravity: [0, -1, 0], rotationRate: [0, 0, 0.1])
        let frame = Frame(timestamp: 0, pixelBuffer: try buffer(), orientation: .up, depth: try buffer(), motion: motion)
        #expect(frame.depth != nil)
        #expect(frame.motion == motion)
        #expect(CVPixelBufferGetWidth(frame.pixelBuffer) == 8)
    }
}
