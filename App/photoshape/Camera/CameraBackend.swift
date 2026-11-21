import AVFoundation
import CaptureKit
import CoreGraphics

/// Camera hardware behind the camera screen.
protocol CameraBackend: AnyObject, Sendable {
    /// Session for the live preview layer; nil when the backend supplies `stillPreview` instead.
    var previewSession: AVCaptureSession? { get }
    /// Upright preview image for backends without a session (simulator).
    var stillPreview: CGImage? { get }

    /// Current camera permission. Asks the user when it has not been decided yet.
    func requestAccess() async -> Bool
    /// Configures on first use, starts the session and returns the lens buttons to show.
    func start() async -> [LensOption]
    func stop() async
    func select(_ lens: LensOption) async
    /// Point of interest in device coordinates (0–1, as `AVCaptureDevice` expects).
    func focus(atDevicePoint point: CGPoint) async
    /// Original photo file data (HEIC, with depth when available). Never contains location.
    func capturePhoto() async throws -> Data
}

enum CameraError: Error {
    case unavailable
    case noPhotoData
}
