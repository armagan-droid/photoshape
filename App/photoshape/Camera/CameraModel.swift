import CaptureKit
import CoreImage
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
    var showingReferences = false
    /// Color adjustments that make the current scene look like the example (spec 05 FR-010); zero without one.
    private(set) var adjustments = LookAdjustments.zero

    let backend: CameraBackend
    let references: ReferenceStore
    let entitlements: Entitlements
    let renderer = LookRenderer()
    private let sampler = FrameSampler()
    private var matchTask: Task<Void, Never>?
    private var exposureBias = 0.0
    private var matchedReferenceID: UUID?
    private var gate = ShutterGate()
    private var isActive = false

    /// Local diagnostics only (stays on the device, Constitution I).
    private static let log = Logger(subsystem: "photoshape", category: "camera")

    init(backend: CameraBackend, references: ReferenceStore, entitlements: Entitlements) {
        self.backend = backend
        self.references = references
        self.entitlements = entitlements
    }

    /// The look the preview and the saved photo use right now.
    var currentLook: LookRecipe {
        var recipe = LookRecipe.natural
        recipe.adjustments = adjustments
        return recipe
    }

    // MARK: - Matching the example (spec 05 FR-009/010, spec 02 FR-004)

    private func startMatching() {
        matchTask?.cancel()
        matchTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.matchOnce()
                try? await Task.sleep(for: .milliseconds(800))
            }
        }
    }

    private func matchOnce() async {
        guard entitlements.isAvailable(.exampleMatching), let reference = references.current else {
            matchedReferenceID = nil
            if adjustments != .zero { adjustments = .zero }
            if exposureBias != 0 { exposureBias = 0; await backend.setExposureBias(0) }
            return
        }
        guard let frame = backend.latestPreviewImage() else { return }
        let sampler = sampler, profile = reference.profile
        guard let result = await Task.detached(priority: .utility, operation: {
            sampler.sample(frame).map { LookMatcher.match(scene: $0, to: profile) }
        }).value else { return }

        // The camera takes over the brightness difference step by step; the look covers what is left.
        let bias = min(1.5, max(-1.5, exposureBias + 0.5 * result.exposureStops))
        if abs(bias - exposureBias) > 0.05 {
            exposureBias = bias
            await backend.setExposureBias(bias)
        }
        // A new example applies at once; after that, changes are eased so the preview does not flicker.
        let isNew = matchedReferenceID != reference.id
        matchedReferenceID = reference.id
        adjustments = isNew ? result.adjustments : adjustments.blended(toward: result.adjustments, by: 0.4)
        Diagnostics.log("match: bias \(String(format: "%.2f", bias)) temp \(String(format: "%.2f", adjustments.temperature)) sat \(String(format: "%.2f", adjustments.saturation))")
    }

    func activate() async {
        guard !isActive else { return }
        isActive = true
        access = await backend.requestAccess() ? .authorized : .denied
        guard access == .authorized else { return }
        lensOptions = await backend.start()
        startMatching()
        if let option = lensOptions.first(where: { $0.kind == selectedLens }) { await backend.select(option) }
    }

    func deactivate() async {
        guard isActive else { return }
        isActive = false
        matchTask?.cancel()
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
        guard gate.press(at: ProcessInfo.processInfo.systemUptime) else { return }
        shutterCount += 1 // feedback right away, before the capture finishes (SC-002)
        // What is on screen at the moment of the press is what gets saved (spec 03 uç durum "eşzamanlılık").
        let recipe = currentLook, renderer = renderer
        let lookRef = references.current.flatMap { ref in
            adjustments == .zero ? nil : EditRecord.LookReference(id: "reference:\(ref.id.uuidString)", version: ref.profile.version, strength: 1)
        }
        Task {
            defer { gate.finish() }
            do {
                let original = try await backend.capturePhoto()
                let processed = try await Task.detached(priority: .userInitiated) {
                    try CaptureProcessor.process(original: original, appVersion: AppInfo.version, look: lookRef,
                                                 applyLook: lookRef == nil ? nil : { renderer.render($0, recipe: recipe, strength: 1) })
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

/// Turns a preview frame into the small color sample the matcher uses.
final class FrameSampler: @unchecked Sendable {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func sample(_ image: CIImage) -> SceneSample? {
        let e = image.extent
        guard e.width > 0, e.height > 0 else { return nil }
        let scale = Double(SceneSample.gridWidth * 4) / e.width
        let small = image.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale)))
        guard let cg = context.createCGImage(small, from: small.extent, format: .RGBA8,
                                             colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { return nil }
        return SceneSample(image: cg)
    }
}

private extension LookAdjustments {
    func blended(toward t: LookAdjustments, by k: Double) -> LookAdjustments {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * k }
        var r = self
        r.exposure = mix(exposure, t.exposure); r.contrast = mix(contrast, t.contrast)
        r.shadows = mix(shadows, t.shadows); r.highlights = mix(highlights, t.highlights)
        r.fade = mix(fade, t.fade); r.temperature = mix(temperature, t.temperature); r.tint = mix(tint, t.tint)
        r.saturation = mix(saturation, t.saturation); r.vibrance = mix(vibrance, t.vibrance)
        r.vignette = mix(vignette, t.vignette); r.grain = mix(grain, t.grain)
        return r
    }
}
