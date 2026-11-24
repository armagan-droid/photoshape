import CaptureKit
import CompositionKit
import CoreImage
import FrameKit
import ImageIO
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
        /// Library identifier once saved: Instagram Feed opens the photo by it (spec 07 Hikâye 1.2).
        var assetID: String?
        /// The look of the press, for the other frames of the series.
        var look: CaptureLook
        /// The series' other frames (originals), kept for this session only (spec 06 FR-005).
        var alternatives: [Data] = []
        var alternativeThumbnails: [UIImage] = []

        init(thumbnail: UIImage, shareURL: URL, look: CaptureLook, alternatives: [Data] = [], alternativeThumbnails: [UIImage] = []) {
            self.thumbnail = thumbnail; self.shareURL = shareURL; self.look = look
            self.alternatives = alternatives; self.alternativeThumbnails = alternativeThumbnails
        }
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
    /// The example card is open (spec 05 Hikâye 7): camera sentences wait until it closes (7.5).
    var showingCard = false
    /// Color adjustments that make the current scene look like the example (spec 05 FR-010); zero without one.
    private(set) var adjustments = LookAdjustments.zero
    /// Warmth given back after the camera's auto white balance (spec 02 FR-003); zero with an example,
    /// whose own color the matching follows instead (FR-004).
    private(set) var baseWarmth = 0.0
    /// Mixed light: white balance follows the subject (spec 02 Hikâye 3.2); neutral otherwise and with an example.
    private(set) var whiteBalanceGains = ChannelGains.neutral

    let backend: CameraBackend
    let references: ReferenceStore
    let entitlements: Entitlements
    let renderer = LookRenderer()
    private let sampler = FrameSampler()
    private var matchTask: Task<Void, Never>?
    /// Brightness the app asks of the camera, in stops (spec 02 FR-009); shown on the example card (spec 05 Hikâye 8.5).
    private(set) var exposureBias = 0.0
    /// The camera's own values, refreshed while the example card is open.
    private(set) var liveExposure: LiveExposure?
    private var matchedReferenceID: UUID?

    /// The one instruction on screen (spec 04 FR-K4), nil when there is nothing to correct.
    private(set) var guidance: GuidanceInstruction?
    /// The shot matches the example's framing and pose (spec 04 Hikâye 5.3, K2.2).
    private(set) var isReady = false
    /// Incremented each time the shot becomes ready (light haptic).
    private(set) var readyCount = 0
    private var stabilizer = GuidanceStabilizer()
    private var analyzeTask: Task<Void, Never>?
    /// Example's brightness preference in stops, from the color matching (spec 05 FR-009).
    private var exampleOffset = 0.0
    private var meteringPoint = CGPoint(x: 0.5, y: 0.5)
    private var lastExposureReason = ExposureDecider.Reason.none
    private var lastTapUptime = -Double.infinity
    private static let tapPriority: TimeInterval = 5
    private var lastAnnounced: [Status: TimeInterval] = [:]
    /// Short sentence about what the app just did (spec 02 FR-010), nil most of the time.
    private(set) var status: Status?
    /// Held down on the preview: show the scene without the app's adjustments (spec 02 FR-011).
    private(set) var isComparing = false
    private var guidedReferenceID: UUID?
    private let finder = SubjectFinder()
    private let motion = PhoneMotion()
    /// The subject found in the last analyzed frame: a person means a series (spec 06 Hikâye 4).
    private var lastLiveSubject: Subject?
    /// After a memory warning, single frames for a while (spec 06 uç durum).
    private var memoryPressureUntil = -Double.infinity
    @ObservationIgnored private var memoryObserver: NSObjectProtocol?
    /// Developer builds: the subject found in the live frame (4:5 frame coordinates), drawn in blue.
    private(set) var debugLiveSubject: Subject?
    private var lastGuideLog = 0.0
    private var gate = ShutterGate()
    private var isActive = false

    /// Local diagnostics only (stays on the device, Constitution I).
    private static let log = Logger(subsystem: "photoshape", category: "camera")

    init(backend: CameraBackend, references: ReferenceStore, entitlements: Entitlements) {
        self.backend = backend
        self.references = references
        self.entitlements = entitlements
        references.entitlements = entitlements
        memoryObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.memoryPressureUntil = ProcessInfo.processInfo.systemUptime + 60 }
        }
    }

    /// White balance the preview and the saved photo use right now; none while comparing (FR-011).
    var currentGains: ChannelGains { isComparing ? .neutral : whiteBalanceGains }

    /// The look the preview and the saved photo use right now.
    var currentLook: LookRecipe {
        var recipe = LookRecipe.natural
        if !isComparing {
            recipe.adjustments = adjustments
            recipe.adjustments.temperature = min(1, adjustments.temperature + baseWarmth)
        }
        return recipe
    }

    // MARK: - Scene analysis: smart exposure + guidance (spec 02 FR-009, spec 04)

    private func startAnalyzing() {
        analyzeTask?.cancel()
        analyzeTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.analyzeOnce()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func analyzeOnce() async {
        guard let frame = backend.latestPreviewImage() else { return }
        let finder = finder, sampler = sampler
        let (live, sample) = await Task.detached(priority: .utility) { () -> (Subject?, SceneSample?) in
            (finder.detect(frame), sampler.sample(frame))
        }.value
        let grid = sample?.luminanceGrid
        lastLiveSubject = live
        let now = ProcessInfo.processInfo.systemUptime
        let values = await backend.currentExposure()
        if showingCard, values != liveExposure { liveExposure = values }
        balanceWhite(cameraKelvin: values?.whiteBalance, sample: sample, subject: live)
        await expose(grid: grid, subject: live, now: now)
        await guide(live: live, grid: grid, now: now)
    }

    /// Smart exposure (spec 02 FR-009, FR-012). A recent tap wins for a few seconds; comparing pauses it.
    private func expose(grid: LuminanceGrid?, subject: Subject?, now: TimeInterval) async {
        guard let grid, !isComparing, now - lastTapUptime > Self.tapPriority else { return }
        let decision = ExposureDecider.decide(grid: grid, subject: subject?.box, currentBias: exposureBias, exampleOffset: exampleOffset)
        if abs(decision.bias - exposureBias) > 0.05 {
            exposureBias = decision.bias
            await backend.setExposureBias(decision.bias)
        }
        if let point = decision.meteringPoint, hypot(point.x - meteringPoint.x, point.y - meteringPoint.y) > 0.05 {
            meteringPoint = point
            await backend.setMeteringPoint(DevicePoint.fromPortraitPreview(point, viewSize: CGSize(width: 1, height: 1)))
        }
        if decision.reason != lastExposureReason {
            lastExposureReason = decision.reason
            switch decision.reason {
            case .subjectBrightened: announce(subject?.kind == .person ? .lightForPerson : .lightForSubject)
            case .subjectDarkened: announce(.brightSubjectBalanced)
            case .highlightsProtected: announce(.brightAreasProtected)
            case .none: break
            }
        }
    }

    /// Keeps part of a warm room's warmth (spec 02 FR-003). Eases toward the target so a lamp switched on
    /// does not make the preview jump (spec 02 uç durum).
    private func balanceWhite(cameraKelvin: Double?, sample: SceneSample?, subject: Subject?) {
        let withoutExample = matchedReferenceID == nil
        let target = withoutExample ? WhiteBalanceDecider.warmth(cameraKelvin: cameraKelvin) : 0
        let next = abs(target - baseWarmth) < 0.01 ? target : baseWarmth + 0.3 * (target - baseWarmth)
        if next != baseWarmth { baseWarmth = next }

        // Window on one side, lamp on the other: balance on the subject (Hikâye 3.2). The frame is read before the
        // look, so the app's own gains do not feed back into the reading.
        let mixed = withoutExample ? sample.flatMap { s in subject.flatMap { WhiteBalanceDecider.mixedLight(
            colors: s.colors, width: SceneSample.gridWidth, height: SceneSample.gridHeight, subject: $0.box) } } : nil
        let goal = WhiteBalanceDecider.gains(for: mixed)
        let eased = whiteBalanceGains.blended(toward: goal, by: 0.25)
        let settled = abs(eased.red - goal.red) < 0.005 && abs(eased.blue - goal.blue) < 0.005 ? goal : eased
        if settled != whiteBalanceGains { whiteBalanceGains = settled }
        if mixed?.isMixed == true, !lastMixed { Diagnostics.log("mixed light: subject b* \(mixed!.subjectCast) around \(mixed!.surroundCast)") }
        lastMixed = mixed?.isMixed == true
    }
    private var lastMixed = false

    /// Guidance toward the example's framing, pose and light (spec 04).
    private func guide(live: Subject?, grid: LuminanceGrid?, now: TimeInterval) async {
        guard let reference = references.current, let example = reference.subject, let aspect = reference.aspect else {
            guidance = nil; isReady = false; guidedReferenceID = nil; debugLiveSubject = nil
            return
        }
        if guidedReferenceID != reference.id { stabilizer = GuidanceStabilizer(); guidedReferenceID = reference.id }
        let liveLight = live.flatMap { subject in grid.flatMap { LightAnalyzer.read($0, subject: subject.box) } }
        let light = CompositionGuide.LightContext(live: liveLight, example: reference.light, isDim: await backend.isLowLight())

        // Compare inside the 4:5 output frame, where the example is fitted exactly as the outline is drawn.
        let c = CropGeometry.normalizedCrop(aspectWidth: 3, aspectHeight: 4)
        let liveInFrame = live?.cropped(to: CGRect(x: c.x, y: c.y, width: c.w, height: c.h))
        let exampleInFrame = example.placed(in: exampleRegion(exampleAspect: CGFloat(aspect)))
        let exampleAngle = reference.angle.flatMap { $0.confidence >= ShotAngleEstimator.minimumConfidence ? $0.angle : nil }
        let raw = CompositionGuide.instruction(live: liveInFrame, example: exampleInFrame, light: light,
                                               phoneDownward: motion.downwardAngle, exampleAngle: exampleAngle)
        #if DEBUG
        debugLiveSubject = liveInFrame
        if now - lastGuideLog > 1 {
            lastGuideLog = now
            func box(_ s: Subject?) -> String {
                guard let s else { return "none" }
                return "\(s.kind.rawValue) cx \(String(format: "%.2f", s.box.midX)) cy \(String(format: "%.2f", s.box.midY)) h \(String(format: "%.2f", s.box.height)) joints \(s.pose?.joints.count ?? 0)"
            }
            let lightText = liveLight.map { String(format: "s/bg %.2f side %.2f", $0.subjectToBackground, $0.sideBalance) } ?? "-"
            Diagnostics.log("guide: live [\(box(liveInFrame))] example [\(box(exampleInFrame))] light [\(lightText) dim \(light.isDim)] bias \(String(format: "%.2f", exposureBias)) raw \(raw?.kind ?? "nil")")
        }
        #endif
        let shown = stabilizer.update(candidate: raw, at: now)
        if shown != guidance { guidance = shown; Diagnostics.log("guidance: \(shown?.kind ?? "ready?")") }
        let ready = shown == nil && raw == nil && live != nil
        if ready && !isReady { readyCount += 1 }
        isReady = ready
    }

    // MARK: - Saying what the app did (spec 02 FR-010)

    enum Status: String {
        case lightForPerson, lightForSubject, brightSubjectBalanced, brightAreasProtected, colorsMatched
        /// Every frame of a series was blurred (spec 06 Hikâye 1.3).
        case holdStill
        var key: String { "status.\(rawValue)" }
    }

    private func announce(_ status: Status) {
        guard !showingCard else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - (lastAnnounced[status] ?? -.infinity) > 10 else { return }
        lastAnnounced[status] = now
        self.status = status
        Diagnostics.log("status: \(status.rawValue)")
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if self.status == status { self.status = nil }
        }
    }

    // MARK: - Before / after (spec 02 FR-011)

    func setComparing(_ on: Bool) {
        guard on != isComparing else { return }
        isComparing = on
        Task {
            // Without the app: no color matching (see `currentLook`) and the camera's own exposure.
            await backend.setExposureBias(on ? 0 : exposureBias)
        }
    }

    // MARK: - Matching the example's colors (spec 05 FR-009/010)

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
            exampleOffset = 0
            if adjustments != .zero { adjustments = .zero }
            return
        }
        guard let frame = backend.latestPreviewImage() else { return }
        let sampler = sampler, profile = reference.profile
        guard let result = await Task.detached(priority: .utility, operation: {
            sampler.sample(frame).map { LookMatcher.match(scene: $0, to: profile) }
        }).value else { return }

        // Brightness belongs to the camera (smart exposure takes it as a preference); the look keeps the rest.
        exampleOffset = result.exposureStops
        var target = result.adjustments
        target.exposure = 0
        let isNew = matchedReferenceID != reference.id
        matchedReferenceID = reference.id
        adjustments = isNew ? target : adjustments.blended(toward: target, by: 0.4)
        if isNew, target.colorChange > 0.15 { announce(.colorsMatched) }
        Diagnostics.log("match: offset \(String(format: "%.2f", exampleOffset)) temp \(String(format: "%.2f", adjustments.temperature)) sat \(String(format: "%.2f", adjustments.saturation))")
    }

    func activate() async {
        guard !isActive else { return }
        isActive = true
        access = await backend.requestAccess() ? .authorized : .denied
        guard access == .authorized else { return }
        lensOptions = await backend.start()
        startMatching()
        startAnalyzing()
        motion.start()
        if let option = lensOptions.first(where: { $0.kind == selectedLens }) { await backend.select(option) }
    }

    func deactivate() async {
        guard isActive else { return }
        isActive = false
        matchTask?.cancel()
        analyzeTask?.cancel()
        motion.stop()
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
        lastTapUptime = ProcessInfo.processInfo.systemUptime
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
        let look = captureLook()
        let subject = lastLiveSubject, rotation = motion.rotationRate
        let constrained = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
            || ProcessInfo.processInfo.systemUptime < memoryPressureUntil
        Task {
            defer { gate.finish() }
            do {
                var count = BurstPlan.frameCount(hasPerson: subject?.kind == .person, phoneRotation: rotation,
                                                 isDim: await backend.isLowLight(), isConstrained: constrained)
                #if DEBUG
                if let forced = UserDefaults.standard.string(forKey: "UITestBurst").flatMap(Int.init) { count = forced }
                #endif
                let frames = try await backend.capturePhotos(count: count)
                // The best frame is saved; the others stay in memory for this session only (spec 06 FR-005, uç durum).
                let (best, selection) = await Task.detached(priority: .userInitiated) {
                    BurstChooser.choose(frames, subject: subject?.box)
                }.value
                if frames.count > 1 { Diagnostics.log("series: \(frames.count) frames, chose \(best) (\(selection?.reason.rawValue ?? "-"))") }
                if selection?.allBlurred == true, frames.count > 1 { announce(.holdStill) }
                let others = frames.indices.filter { $0 != best }.map { frames[$0] }
                await processAndSave(frames[best], look: look, alternatives: others)
            } catch {
                // Capture failures are not shown as errors (Constitution II); the shutter simply becomes ready again.
                Self.log.error("capture failed: \(String(describing: error), privacy: .public)")
                Diagnostics.log("capture failed: \(error)")
            }
        }
    }

    /// Everything the saved photo needs from the moment of the press.
    struct CaptureLook: @unchecked Sendable {
        var recipe: LookRecipe
        var gains: ChannelGains
        var reference: EditRecord.LookReference?
    }

    private func captureLook() -> CaptureLook {
        let recipe = currentLook, gains = currentGains
        let reference = references.current.flatMap { ref in
            adjustments == .zero ? nil : EditRecord.LookReference(id: "reference:\(ref.id.uuidString)", version: ref.profile.version, strength: 1)
        } ?? (recipe.adjustments.temperature != 0 || !gains.isNeutral
              ? EditRecord.LookReference(id: "base:white-balance", version: 1, strength: 1) : nil)
        return CaptureLook(recipe: recipe, gains: gains, reference: reference)
    }

    /// Renders the look, writes the share copy and saves to Photos; `lastCapture` follows.
    private func processAndSave(_ original: Data, look: CaptureLook, alternatives: [Data]) async {
        let renderer = renderer
        do {
            let processed = try await Task.detached(priority: .userInitiated) {
                try CaptureProcessor.process(original: original, appVersion: AppInfo.version, look: look.reference,
                                             applyLook: look.reference == nil ? nil : { renderer.render($0, recipe: look.recipe, strength: 1, gains: look.gains) })
            }.value
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("photoshape-\(UUID().uuidString).jpg")
            try processed.shareJPEG.write(to: url)
            let thumbs = await Task.detached(priority: .utility) { alternatives.compactMap(BurstChooser.thumbnail) }.value
            let capture = LastCapture(thumbnail: UIImage(cgImage: processed.thumbnail), shareURL: url, look: look,
                                      alternatives: alternatives, alternativeThumbnails: thumbs.map(UIImage.init(cgImage:)))
            lastCapture = capture
            switch await PhotoLibrarySaver.save(processed, formatIdentifier: AppInfo.bundleIdentifier) {
            case .saved(let revertible, let assetID):
                if lastCapture?.id == capture.id {
                    if revertible { lastCapture?.revertible = true }
                    lastCapture?.assetID = assetID
                }
            case .denied: show(.saveDenied)
            case .failed: show(.saveFailed)
            }
        } catch {
            Self.log.error("processing failed: \(String(describing: error), privacy: .public)")
            Diagnostics.log("processing failed: \(error)")
        }
    }

    /// "Diğer kareler" (spec 06 Hikâye 3): the picked frame is added as a new photo (open question 2 default:
    /// add-only access is enough), and becomes the one under review.
    func chooseAlternative(_ index: Int, of capture: LastCapture) {
        guard capture.alternatives.indices.contains(index) else { return }
        var rest = capture.alternatives
        let picked = rest.remove(at: index)
        Task {
            await processAndSave(picked, look: capture.look, alternatives: rest)
            reviewing = lastCapture
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

    /// Rough size of the color change, for deciding whether it is worth mentioning.
    var colorChange: Double {
        [abs(temperature), abs(tint), abs(saturation), abs(contrast), fade, vignette].max() ?? 0
    }
}

/// Finds the main subject in a preview frame with Vision, at a small size (spec 04 FR-K1).
final class SubjectFinder: @unchecked Sendable {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func detect(_ image: CIImage) -> Subject? {
        let e = image.extent
        guard e.width > 0 else { return nil }
        let scale = 480 / max(e.width, e.height)
        let small = image.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale)))
        guard let cg = context.createCGImage(small, from: small.extent) else { return nil }
        return SubjectDetector.detect(in: cg)
    }
}

/// Scores the frames of a series and picks one (spec 06): sharpness on the live subject's box, eyes with Vision.
enum BurstChooser {
    static func choose(_ frames: [Data], subject: CGRect?) -> (Int, BurstSelection?) {
        guard frames.count > 1 else { return (0, nil) }
        let qualities = frames.map { data -> FrameQuality in
            guard let image = upright(data, maxSide: 1024) else { return FrameQuality(sharpness: 0) }
            return FrameQuality(sharpness: Sharpness.measure(image, subject: subject), faces: FaceEyes.detect(in: image))
        }
        let selection = BurstSelector.choose(qualities)
        return (selection?.index ?? 0, selection)
    }

    static func thumbnail(_ data: Data) -> CGImage? { upright(data, maxSide: 300) }

    static func upright(_ data: Data, maxSide: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxSide]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

