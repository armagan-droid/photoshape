import CaptureKit
import CoreImage

/// Camera hardware behind the camera screen.
protocol CameraBackend: AnyObject, Sendable {
    /// Newest camera frame, upright (portrait), preview-sized. Read by the look preview on every draw.
    func latestPreviewImage() -> CIImage?

    /// Current camera permission. Asks the user when it has not been decided yet.
    func requestAccess() async -> Bool
    /// Configures on first use, starts the session and returns the lens buttons to show.
    func start() async -> [LensOption]
    func stop() async
    func select(_ lens: LensOption) async
    /// Brightness target relative to auto exposure, in stops; clamped to what the device allows (spec 02 FR-004).
    func setExposureBias(_ stops: Double) async
    /// Where auto exposure measures (device coordinates), without changing focus (spec 02 FR-009).
    func setMeteringPoint(_ point: CGPoint) async
    /// Whether the camera is working at very high sensitivity, i.e. the scene is dim (spec 04 FR-L2).
    func isLowLight() async -> Bool
    /// What the camera is doing right now, shown next to the example's settings (spec 05 Hikâye 8.5).
    func currentExposure() async -> LiveExposure?
    /// Point of interest in device coordinates (0–1, as `AVCaptureDevice` expects).
    func focus(atDevicePoint point: CGPoint) async
    /// Original photo file data (HEIC, with depth when available). Never contains location.
    func capturePhoto() async throws -> Data
    /// Several frames from one press, one shutter sound (spec 06 Hikâye 1.1). Falls back to one frame when the
    /// camera cannot take a series right now.
    func capturePhotos(count: Int) async throws -> [Data]
}

extension CameraBackend {
    func capturePhotos(count: Int) async throws -> [Data] { [try await capturePhoto()] }
}

/// The camera's own values at this moment (spec 05 Hikâye 8.5).
struct LiveExposure: Sendable, Equatable {
    /// Seconds.
    var exposureTime: Double
    var iso: Double
    var fNumber: Double
    /// White balance the camera uses, K.
    var whiteBalance: Double?
}

enum CameraError: Error {
    case unavailable
    case noPhotoData
}
