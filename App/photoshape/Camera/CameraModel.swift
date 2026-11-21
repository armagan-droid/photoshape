import CaptureKit
import OSLog
import SwiftUI
import UIKit

/// State of the camera screen. Talks to the backend; holds no AVFoundation objects itself.
@MainActor @Observable
final class CameraModel {
    enum Access { case unknown, authorized, denied }

    struct LastCapture: Identifiable {
        let id = UUID()
        let thumbnail: UIImage
        /// 4:5 JPEG in the temporary directory; kept for the session so it can be shared even if saving failed.
        let shareURL: URL
    }

    struct Notice: Identifiable, Equatable {
        enum Kind { case saveDenied, saveFailed }
        let id = UUID()
        let kind: Kind
    }

    struct FocusMarker: Identifiable, Equatable {
        let id = UUID()
        let location: CGPoint
    }

    private(set) var access: Access = .unknown
    private(set) var lensOptions: [LensOption] = []
    private(set) var selectedLens: LensKind = .default
    private(set) var lastCapture: LastCapture?
    private(set) var notice: Notice?
    private(set) var focusMarker: FocusMarker?
    /// Incremented on every accepted shutter press; drives the flash and the haptic.
    private(set) var shutterCount = 0
    var reviewing: LastCapture?

    let backend: CameraBackend
    private var gate = ShutterGate()
    private var isActive = false

    /// Local diagnostics only (stays on the device, Constitution I).
    private static let log = Logger(subsystem: "photoshape", category: "camera")

    init(backend: CameraBackend) { self.backend = backend }

    func activate() async {
        guard !isActive else { return }
        isActive = true
        access = await backend.requestAccess() ? .authorized : .denied
        guard access == .authorized else { return }
        lensOptions = await backend.start()
        if let option = lensOptions.first(where: { $0.kind == selectedLens }) { await backend.select(option) }
    }

    func deactivate() async {
        guard isActive else { return }
        isActive = false
        await backend.stop()
    }

    func select(_ option: LensOption) {
        guard option.kind != selectedLens else { return }
        selectedLens = option.kind
        Task { await backend.select(option) }
    }

    func tapToFocus(viewPoint: CGPoint, devicePoint: CGPoint) {
        focusMarker = FocusMarker(location: viewPoint)
        let marker = focusMarker
        Task {
            await backend.focus(atDevicePoint: devicePoint)
            try? await Task.sleep(for: .seconds(1))
            if focusMarker == marker { focusMarker = nil }
        }
    }

    func shutter() {
        guard access == .authorized, gate.press(at: ProcessInfo.processInfo.systemUptime) else { return }
        shutterCount += 1 // feedback right away, before the capture finishes (SC-002)
        Task {
            defer { gate.finish() }
            do {
                let original = try await backend.capturePhoto()
                let processed = try await Task.detached(priority: .userInitiated) {
                    try CaptureProcessor.process(original: original, appVersion: AppInfo.version)
                }.value
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("photoshape-\(UUID().uuidString).jpg")
                try processed.shareJPEG.write(to: url)
                lastCapture = LastCapture(thumbnail: UIImage(cgImage: processed.thumbnail), shareURL: url)

                switch await PhotoLibrarySaver.save(processed, formatIdentifier: AppInfo.bundleIdentifier) {
                case .saved: break
                case .denied: show(.saveDenied)
                case .failed: show(.saveFailed)
                }
            } catch {
                // Capture failures are not shown as errors (Constitution II); the shutter simply becomes ready again.
                Self.log.error("capture failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func show(_ kind: Notice.Kind) {
        let notice = Notice(kind: kind)
        self.notice = notice
        Task {
            try? await Task.sleep(for: .seconds(5))
            if self.notice == notice { self.notice = nil }
        }
    }
}

enum AppInfo {
    static var bundleIdentifier: String { Bundle.main.bundleIdentifier ?? "app.photoshape.ios" }
    static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "0") (\(info?["CFBundleVersion"] as? String ?? "0"))"
    }
}
