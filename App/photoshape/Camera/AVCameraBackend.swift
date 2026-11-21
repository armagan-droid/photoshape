import AVFoundation
import CaptureKit
import FrameKit

/// AVFoundation camera. All session and device work happens on `queue`; that is what makes the
/// `@unchecked Sendable` safe.
final class AVCameraBackend: NSObject, CameraBackend, @unchecked Sendable {
    let session = AVCaptureSession()
    let frameSource = CameraFrameSource()

    private let queue = DispatchQueue(label: "photoshape.camera.session")
    private let videoQueue = DispatchQueue(label: "photoshape.camera.frames")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var device: AVCaptureDevice?
    private var lensOptions: [LensOption] = []
    private var isConfigured = false
    private var inFlight: [Int64: PhotoCaptureDelegate] = [:]
    private var observers: [NSObjectProtocol] = []

    /// Photos stay near 12 MP: enough for Instagram, quick to capture and save (SC-002).
    private static let maxPhotoPixels = 12_600_000

    var previewSession: AVCaptureSession? { session }
    var stillPreview: CGImage? { nil }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    // MARK: - CameraBackend

    func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    func start() async -> [LensOption] {
        await onQueue {
            if !self.isConfigured { self.configure() }
            if !self.session.isRunning { self.session.startRunning() }
            return self.lensOptions
        }
    }

    func stop() async {
        await onQueue { if self.session.isRunning { self.session.stopRunning() } }
    }

    func select(_ lens: LensOption) async {
        await onQueue {
            guard let device = self.device else { return }
            let factor = min(max(lens.zoomFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            self.withLockedDevice { $0.ramp(toVideoZoomFactor: factor, withRate: 12) } // short, soft transition
        }
    }

    func focus(atDevicePoint point: CGPoint) async {
        await onQueue {
            self.withLockedDevice { device in
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                // A clear scene change returns to continuous auto (spec 01 Hikâye 3.2).
                device.isSubjectAreaChangeMonitoringEnabled = true
            }
        }
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.session.isRunning, self.photoOutput.connection(with: .video) != nil else {
                    continuation.resume(throwing: CameraError.unavailable); return
                }
                let settings: AVCapturePhotoSettings
                if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                } else {
                    settings = AVCapturePhotoSettings()
                }
                settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
                settings.photoQualityPrioritization = .balanced
                settings.flashMode = .off
                if self.photoOutput.isDepthDataDeliveryEnabled {
                    settings.isDepthDataDeliveryEnabled = true
                    settings.embedsDepthDataInPhoto = true
                }
                let id = settings.uniqueID
                let delegate = PhotoCaptureDelegate { result in
                    self.queue.async { self.inFlight[id] = nil }
                    continuation.resume(with: result)
                }
                self.inFlight[id] = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    // MARK: - Configuration (on queue)

    private func configure() {
        isConfigured = true
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .back)
        // Discovery returns devices in the order of `deviceTypes`: the richest virtual device first.
        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
        self.device = device

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .balanced
            if let dims = device.activeFormat.supportedMaxPhotoDimensions
                .filter({ Int($0.width) * Int($0.height) <= Self.maxPhotoPixels })
                .max(by: { $0.width * $0.height < $1.width * $1.height }) {
                photoOutput.maxPhotoDimensions = dims
            }
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            // Portrait only; a sideways hold is ignored (spec 01 karar 1).
            if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        if session.canAddOutput(videoOutput) {
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(frameSource, queue: videoQueue)
            session.addOutput(videoOutput)
        }

        let constituents = device.constituentDevices.map(\.deviceType)
        let caps = CameraCapabilities(
            hasUltraWide: constituents.contains(.builtInUltraWideCamera),
            hasTelephoto: constituents.contains(.builtInTelephotoCamera),
            switchOverZoomFactors: device.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue),
            maxZoomFactor: Double(device.maxAvailableVideoZoomFactor))
        lensOptions = LensCatalog.options(for: caps)

        withLockedDevice { device in
            if let normal = self.lensOptions.first(where: { $0.kind == .default }) {
                device.videoZoomFactor = CGFloat(normal.zoomFactor)
            }
            self.resetFocus(device)
        }
        observe(device)
        applyThermalState()
    }

    private func observe(_ device: AVCaptureDevice) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: device, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async { self.withLockedDevice(self.resetFocus) }
        })
        // Media services reset: restart; other interruptions (calls, Control Center) resume on their own.
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] note in
            guard let self, (note.userInfo?[AVCaptureSessionErrorKey] as? AVError)?.code == .mediaServicesWereReset else { return }
            self.queue.async { if !self.session.isRunning { self.session.startRunning() } }
        })
        observers.append(center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async { self.applyThermalState() }
        })
    }

    private func resetFocus(_ device: AVCaptureDevice) {
        let center = CGPoint(x: 0.5, y: 0.5)
        if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = center }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = center }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        device.isSubjectAreaChangeMonitoringEnabled = false
    }

    /// When the phone gets hot the preview runs at 24 fps; captures continue (spec 01 uç durum "ısınma").
    private func applyThermalState() {
        let hot = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
        withLockedDevice { device in
            let supports24 = device.activeFormat.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 24 && 24 <= $0.maxFrameRate }
            device.activeVideoMinFrameDuration = hot && supports24 ? CMTime(value: 1, timescale: 24) : .invalid
        }
    }

    private func withLockedDevice(_ body: (AVCaptureDevice) -> Void) {
        guard let device, (try? device.lockForConfiguration()) != nil else { return }
        body(device)
        device.unlockForConfiguration()
    }

    private func onQueue<T: Sendable>(_ body: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: body()) }
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Result<Data, Error>) -> Void
    private var data: Data?
    private var error: Error?

    init(completion: @escaping (Result<Data, Error>) -> Void) { self.completion = completion }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { self.error = error } else { data = photo.fileDataRepresentation() }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error ?? self.error { completion(.failure(error)) }
        else if let data { completion(.success(data)) }
        else { completion(.failure(CameraError.noPhotoData)) }
    }
}
