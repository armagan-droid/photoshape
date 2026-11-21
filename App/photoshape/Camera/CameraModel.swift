import CaptureKit
import LookKit
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
        /// Saved with the 4:5 edit attached, so Photos can revert to the full frame (Hikâye 4.3).
        var revertible = false
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
    /// Incremented when the shutter is pressed on a locked look (light "no" haptic; spec 07 adds the paywall).
    private(set) var lockedPressCount = 0

    let backend: CameraBackend
    let looks: LookSelection
    let entitlements: Entitlements
    let renderer = LookRenderer()
    private var gate = ShutterGate()
    private var isActive = false

    /// Local diagnostics only (stays on the device, Constitution I).
    private static let log = Logger(subsystem: "photoshape", category: "camera")

    init(backend: CameraBackend, looks: LookSelection, entitlements: Entitlements) {
        self.backend = backend
        self.looks = looks
        self.entitlements = entitlements
    }

    /// Whether the shutter shows the lock (Hikâye 5.2): the look can be tried live but not captured.
    var isSelectedLookLocked: Bool { !entitlements.isAvailable(looks.selected) }

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

    func tapToFocus(viewPoint: CGPoint, viewSize: CGSize) {
        let devicePoint = DevicePoint.fromPortraitPreview(viewPoint, viewSize: viewSize)
        Diagnostics.log("tap at view \(viewPoint) in \(viewSize) → device \(devicePoint)")
        focusMarker = FocusMarker(location: viewPoint)
        let marker = focusMarker
        Task {
            await backend.focus(atDevicePoint: devicePoint)
            try? await Task.sleep(for: .seconds(1))
            if focusMarker == marker { focusMarker = nil }
        }
    }

    func shutter() {
        guard access == .authorized else { return }
        guard !isSelectedLookLocked else { lockedPressCount += 1; return }
        guard gate.press(at: ProcessInfo.processInfo.systemUptime) else { return }
        shutterCount += 1 // feedback right away, before the capture finishes (SC-002)
        // The look at the moment of the press is what gets saved (spec 03 uç durum "eşzamanlılık").
        let recipe = looks.selected, strength = looks.strength, renderer = renderer
        let lookRef = recipe.id == LookRecipe.natural.id || strength == 0
            ? nil : EditRecord.LookReference(id: recipe.id, version: recipe.version, strength: strength)
        Task {
            defer { gate.finish() }
            do {
                let original = try await backend.capturePhoto()
                let processed = try await Task.detached(priority: .userInitiated) {
                    try CaptureProcessor.process(original: original, appVersion: AppInfo.version, look: lookRef,
                                                 applyLook: lookRef == nil ? nil : { renderer.render($0, recipe: recipe, strength: strength) })
                }.value
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("photoshape-\(UUID().uuidString).jpg")
                try processed.shareJPEG.write(to: url)
                let capture = LastCapture(thumbnail: UIImage(cgImage: processed.thumbnail), shareURL: url)
                lastCapture = capture

                switch await PhotoLibrarySaver.save(processed, formatIdentifier: AppInfo.bundleIdentifier) {
                case .saved(let revertible):
                    if revertible, lastCapture?.id == capture.id { lastCapture?.revertible = true }
                case .denied: show(.saveDenied)
                case .failed: show(.saveFailed)
                }
            } catch {
                // Capture failures are not shown as errors (Constitution II); the shutter simply becomes ready again.
                Self.log.error("capture failed: \(String(describing: error), privacy: .public)")
                Diagnostics.log("capture failed: \(error)")
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
