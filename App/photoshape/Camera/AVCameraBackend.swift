import AVFoundation
import CaptureKit
import CoreImage
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
    /// Subject-area changes right after a tap come from the hand that tapped; ignore them for a moment.
    private var lastTapUptime: TimeInterval = 0
    private static let tapGracePeriod: TimeInterval = 2

    /// Photos stay near 12 MP: enough for Instagram, quick to capture and save (SC-002).
    private static let maxPhotoPixels = 12_600_000

    func latestPreviewImage() -> CIImage? { frameSource.latestImage() }

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

    func setExposureBias(_ stops: Double) async {
        await onQueue {
            self.withLockedDevice { device in
                let bias = Float(stops).clamped(to: device.minExposureTargetBias...device.maxExposureTargetBias)
                device.setExposureTargetBias(bias, completionHandler: nil)
            }
        }
    }

    func setMeteringPoint(_ point: CGPoint) async {
        await onQueue {
            self.withLockedDevice { device in
                guard device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) else { return }
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
            }
        }
    }

    func isLowLight() async -> Bool {
        await onQueue {
            guard let device = self.device else { return false }
            // Auto exposure keeps the image mid-bright even in a dark café; the sensitivity it needs tells the truth.
            let isoLimit = min(1600, device.activeFormat.maxISO * 0.6)
            return device.iso >= isoLimit || device.exposureDuration.seconds >= 1.0 / 20
        }
    }

    func currentExposure() async -> LiveExposure? {
        await onQueue {
            guard let device = self.device else { return nil }
            var kelvin: Double?
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                let gains = device.deviceWhiteBalanceGains
                let max = device.maxWhiteBalanceGain
                let clamped = AVCaptureDevice.WhiteBalanceGains(redGain: min(Swift.max(gains.redGain, 1), max),
                                                                greenGain: min(Swift.max(gains.greenGain, 1), max),
                                                                blueGain: min(Swift.max(gains.blueGain, 1), max))
                kelvin = Double(device.temperatureAndTintValues(for: clamped).temperature)
            }
            return LiveExposure(exposureTime: device.exposureDuration.seconds, iso: Double(device.iso),
                                fNumber: Double(device.lensAperture), whiteBalance: kelvin)
        }
    }

    func focus(atDevicePoint point: CGPoint) async {
        await onQueue {
            self.lastTapUptime = ProcessInfo.processInfo.systemUptime
            self.withLockedDevice { device in
                // Continuous modes keep focus and brightness on the tapped point while it stays in view.
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
                Diagnostics.log("focus at device point \(point) on \(device.localizedName)")
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
            // Screen-sized frames: the look preview renders every frame (spec 03 SC-004).
            // (Must turn off automatic sizing first, or AVFoundation throws.)
            videoOutput.automaticallyConfiguresOutputBufferDimensions = false
            videoOutput.deliversPreviewSizedOutputBuffers = true
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
            // Handheld: no slower than 1/30 s; auto exposure raises sensitivity instead (spec 02 FR-012, SC-007).
            let limit = CMTime(value: 1, timescale: 30)
            if device.activeFormat.maxExposureDuration > limit, device.activeFormat.minExposureDuration <= limit {
                device.activeMaxExposureDuration = limit
            }
        }
        observe(device)
        applyThermalState()
    }

    private func observe(_ device: AVCaptureDevice) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: device, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                let sinceTap = ProcessInfo.processInfo.systemUptime - self.lastTapUptime
                guard sinceTap > Self.tapGracePeriod else {
                    Diagnostics.log("subject area changed \(String(format: "%.1f", sinceTap)) s after tap: ignored")
                    return
                }
                Diagnostics.log("subject area changed: back to continuous auto")
                self.withLockedDevice(self.resetFocus)
            }
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

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float { Swift.min(range.upperBound, Swift.max(range.lowerBound, self)) }
}
