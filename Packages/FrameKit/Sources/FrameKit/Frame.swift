import CoreVideo
import Foundation
import ImageIO

/// One camera frame, as a value. Analysis code receives this instead of a camera object (Constitution IV).
///
/// `@unchecked Sendable`: pixel buffers are treated as read-only once a frame is emitted.
public struct Frame: @unchecked Sendable {
    /// Seconds on the source's clock (monotonic within one source).
    public let timestamp: TimeInterval
    public let pixelBuffer: CVPixelBuffer
    /// How the buffer must be rotated to appear upright on screen.
    public let orientation: CGImagePropertyOrientation
    /// Depth or disparity aligned with `pixelBuffer`, when the source provides it.
    public let depth: CVPixelBuffer?
    public let motion: MotionSample?

    public init(timestamp: TimeInterval, pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                depth: CVPixelBuffer? = nil, motion: MotionSample? = nil) {
        self.timestamp = timestamp
        self.pixelBuffer = pixelBuffer
        self.orientation = orientation
        self.depth = depth
        self.motion = motion
    }
}

/// Device motion at frame time.
public struct MotionSample: Sendable, Hashable {
    /// Gravity in device coordinates, in g (x right, y up, z out of the screen).
    public var gravity: SIMD3<Double>
    /// Rotation rate in rad/s.
    public var rotationRate: SIMD3<Double>

    public init(gravity: SIMD3<Double>, rotationRate: SIMD3<Double>) {
        self.gravity = gravity
        self.rotationRate = rotationRate
    }
}

/// Produces frames. The camera implementation lives in the app; tests feed recorded frames.
/// Frame rhythm (every frame or a sampled subset) is the source's decision.
public protocol FrameSource: AnyObject, Sendable {
    /// A single-consumer stream of frames. Calling it again replaces the previous consumer.
    func frames() -> AsyncStream<Frame>
}

/// Replays a fixed list of frames, in order, then finishes. For tests.
public final class RecordedFrameSource: FrameSource {
    private let recorded: [Frame]

    public init(_ frames: [Frame]) { recorded = frames }

    public func frames() -> AsyncStream<Frame> {
        let recorded = recorded
        return AsyncStream { continuation in
            for frame in recorded { continuation.yield(frame) }
            continuation.finish()
        }
    }
}
