import AVFoundation
import FrameKit

/// Live frames for analysis layers (spec 01 FR-010). Only the newest frame is buffered, so a slow
/// consumer never holds up the camera.
final class CameraFrameSource: NSObject, FrameSource, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<Frame>.Continuation?

    func frames() -> AsyncStream<Frame> {
        let (stream, continuation) = AsyncStream<Frame>.makeStream(bufferingPolicy: .bufferingNewest(1))
        lock.withLock {
            self.continuation?.finish()
            self.continuation = continuation
        }
        return stream
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let continuation = lock.withLock({ continuation }),
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Buffers stay in sensor orientation; for the back camera held upright that is "right".
        continuation.yield(Frame(timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds,
                                 pixelBuffer: buffer, orientation: .right))
    }
}
