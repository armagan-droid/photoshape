import CaptureKit
import ImageIO
import LookKit
import SwiftUI

/// The camera, set up from the chosen example photo (spec 05 Hikâye 0). Without an example the user first sees the
/// prompt to pick one. Layout: example chip on top, preview with lens buttons inside, shutter row.
struct CameraScreen: View {
    @Bindable var model: CameraModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var flash = false
    /// Sheet hand-offs: the card opens Örneklerim, and a pick in Örneklerim opens the card (spec 05 Hikâye 7).
    @State private var referencesAfterCard = false
    @State private var cardAfterReferences = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.access {
            case .unknown: EmptyView()
            case .denied: PermissionDeniedView()
            case .authorized:
                if needsPrompt { ReferencePromptView(store: model.references) } else { camera }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await injectTestReferenceIfAsked()
            await model.activate()
        }
        .sheet(isPresented: $model.showingReferences, onDismiss: {
            if cardAfterReferences { cardAfterReferences = false; if model.references.current != nil { model.showingCard = true } }
        }) { ReferencesSheet(store: model.references) }
        .sheet(isPresented: $model.showingCard, onDismiss: {
            if referencesAfterCard { referencesAfterCard = false; model.showingReferences = true }
        }) {
            if let reference = model.references.current {
                ExampleCardView(store: model.references, reference: reference, change: {
                    referencesAfterCard = true
                    model.showingCard = false
                }, shootWithout: {
                    model.references.shootWithoutExample()
                    model.showingCard = false
                }, live: model.liveExposure, appBias: model.exposureBias, lensKey: "lens.\(model.selectedLens.rawValue)")
            }
        }
        // Every pick opens the card, not the launch with the last example (spec 05 Hikâye 7.1).
        .onChange(of: model.references.selectionCount) {
            if model.showingReferences { cardAfterReferences = true } else { model.showingCard = true }
        }
        .onChange(of: scenePhase) { _, phase in
            Task {
                if phase == .active { await model.activate() } else if phase == .background { await model.deactivate() }
            }
        }
        .sheet(item: $model.reviewing) { capture in
            // Reads the model so the revert note can appear once saving finishes.
            ReviewView(capture: model.lastCapture?.id == capture.id ? model.lastCapture ?? capture : capture)
        }
    }

    private var needsPrompt: Bool {
        #if DEBUG
        // Launch arguments arrive as strings ("NO"), so read it as a string.
        if UserDefaults.standard.string(forKey: "ReferencePrompt")?.uppercased() == "NO" { return false }
        #endif
        return model.references.current == nil && !model.references.skippedPrompt
    }

    private var camera: some View {
        VStack(spacing: 0) {
            // With an example the icon opens its card; without one, Örneklerim (spec 05 Hikâye 0.2, 7.2).
            ReferenceChip(store: model.references) {
                if model.references.current != nil { model.showingCard = true } else { model.showingReferences = true }
            }
                .frame(minHeight: 44)
                .padding(.bottom, 6)
            preview
            Spacer(minLength: 8)
            controls
            Spacer(minLength: 8)
        }
        .overlay(alignment: .top) { noticeBanner }
    }

    /// Developer builds: `-UITestReference <sample file>` adds a bundled sample as the example (UI tests cannot
    /// drive the system photo picker reliably).
    private func injectTestReferenceIfAsked() async {
        #if DEBUG
        guard let name = UserDefaults.standard.string(forKey: "UITestReference"),
              let dir = try? LookCatalog.bundled().directory,
              var data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return }
        // `-UITestReferenceCameraData YES`: the sample gets iPhone-like camera data (spec 05 Hikâye 8.1).
        if UserDefaults.standard.bool(forKey: "UITestReferenceCameraData") { data = Self.withTestCameraData(data) }
        await model.references.add(imageData: data)
        #endif
    }

    #if DEBUG
    private static func withTestCameraData(_ data: Data) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return data }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else { return data }
        let exif: [String: Any] = [
            kCGImagePropertyExifExposureTime as String: 1.0 / 125, kCGImagePropertyExifFNumber as String: 1.78,
            kCGImagePropertyExifISOSpeedRatings as String: [64], kCGImagePropertyExifFocalLength as String: 6.86,
            kCGImagePropertyExifFocalLenIn35mmFilm as String: 24, kCGImagePropertyExifExposureBiasValue as String: -0.7,
            kCGImagePropertyExifFlash as String: 16,
        ]
        CGImageDestinationAddImage(dest, image, [kCGImagePropertyExifDictionary as String: exif,
                                                 kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFModel as String: "iPhone 15 Pro"]] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : data
    }
    #endif

    private var preview: some View {
        LookPreview(source: model.backend.latestPreviewImage, look: model.currentLook,
                    strength: 1, gains: model.currentGains, renderer: model.renderer, onTap: { point, size in
            model.tapToFocus(viewPoint: point, viewSize: size)
        }, onHold: model.setComparing)
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .overlay { FrameMask().allowsHitTesting(false) }
        .overlay {
            if let ref = model.references.current, ref.subject != nil || model.references.ghost(ref.id) != nil {
                GhostOverlay(ghost: model.references.ghost(ref.id), subject: ref.subject, aspect: ref.aspect ?? 0.8,
                             isReady: model.isReady, debugLive: model.debugLiveSubject)
            }
        }
        .overlay(alignment: .top) {
            // One sentence at a time (Constitution II): comparing > guidance > what the app did.
            Group {
                if model.showingCard {
                    EmptyView() // camera sentences wait for the card (spec 05 Hikâye 7.5)
                } else if model.isComparing {
                    StatusCaption(key: "compare.without").accessibilityIdentifier("comparing")
                } else if let instruction = model.guidance {
                    GuidanceBanner(instruction: instruction)
                } else if let status = model.status {
                    StatusCaption(key: status.key).accessibilityIdentifier("status")
                }
            }
            .padding(.top, 34)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: model.status)
        .animation(.easeInOut(duration: 0.15), value: model.isComparing)
        .animation(.easeInOut(duration: 0.25), value: model.guidance)
        .overlay { focusMarker.allowsHitTesting(false) }
        .overlay(alignment: .bottom) {
            LensPicker(options: model.lensOptions, selected: model.selectedLens, select: model.select)
                .padding(.bottom, 10)
        }
        .overlay { Color.white.opacity(flash ? 0.8 : 0).allowsHitTesting(false) }
        .clipped()
        .onChange(of: model.shutterCount) {
            flash = true
            withAnimation(.easeOut(duration: 0.25)) { flash = false }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.shutterCount)
        .sensoryFeedback(.success, trigger: model.readyCount)
    }

    @ViewBuilder private var focusMarker: some View {
        GeometryReader { _ in
            if let marker = model.focusMarker {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.yellow, lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .position(marker.location)
                    .transition(.opacity)
                    .id(marker.id)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.focusMarker)
    }

    private var controls: some View {
        HStack {
            Group {
                if let last = model.lastCapture {
                    Button { model.reviewing = last } label: {
                        Image(uiImage: last.thumbnail)
                            .resizable()
                            .aspectRatio(4.0 / 5.0, contentMode: .fill)
                            .frame(width: 52, height: 65)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.7), lineWidth: 1))
                    }
                    .accessibilityLabel(Text("camera.lastPhoto"))
                    .accessibilityIdentifier("lastPhoto")
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Color.clear
                }
            }
            .frame(width: 72, height: 72)
            .animation(.spring(duration: 0.3), value: model.lastCapture?.id)

            Spacer()
            ShutterButton(isReady: model.isReady, action: model.shutter)
            Spacer()
            Color.clear.frame(width: 72, height: 72)
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder private var noticeBanner: some View {
        if let notice = model.notice {
            VStack(spacing: 8) {
                switch notice.kind {
                case .saveDenied:
                    Text("save.denied")
                    Button("common.openSettings", action: openSettings).bold()
                case .saveFailed:
                    Text("save.failed")
                }
            }
            .font(.callout)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.top, 8).padding(.horizontal, 24)
            .accessibilityIdentifier("notice")
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Dims everything outside the 4:5 output frame so the user sees what will be cropped (spec 01 Hikâye 1.1).
/// Uses the same geometry as the saved crop (spec 01 FR-002).
struct FrameMask: View {
    var body: some View {
        GeometryReader { geo in
            let crop = CropGeometry.normalizedCrop(aspectWidth: geo.size.width, aspectHeight: geo.size.height)
            let rect = CGRect(x: crop.x * geo.size.width, y: crop.y * geo.size.height,
                              width: crop.w * geo.size.width, height: crop.h * geo.size.height)
            Path { p in
                p.addRect(CGRect(origin: .zero, size: geo.size))
                p.addRect(rect)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        }
    }
}

struct ShutterButton: View {
    var isLocked = false
    /// Thin "ready" ring when the shot matches the example (spec 04 Hikâye 5.3).
    var isReady = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(isReady ? Color.green : .white, lineWidth: 4).frame(width: 76, height: 76)
                    .animation(.easeInOut(duration: 0.25), value: isReady)
                Circle().fill(.white.opacity(isLocked ? 0.5 : 1)).frame(width: 62, height: 62)
                if isLocked {
                    Image(systemName: "lock.fill").font(.title2).foregroundStyle(.black)
                }
            }
        }
        .buttonStyle(ShutterPressStyle())
        .accessibilityLabel(Text(isLocked ? "camera.shutterLocked" : "camera.shutter"))
        .accessibilityIdentifier("shutter")
        .accessibilityValue(Text(isReady ? "camera.ready" : ""))
    }
}

private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}

/// Lens buttons, drawn inside the preview (plan layout).
struct LensPicker: View {
    let options: [LensOption]
    let selected: LensKind
    let select: (LensOption) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.kind) { option in
                let isSelected = option.kind == selected
                Button { select(option) } label: {
                    Text(label(for: option.kind))
                        .font(.footnote.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.yellow : .white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.black.opacity(isSelected ? 0.55 : 0.35)))
                }
                .accessibilityIdentifier("lens.\(option.kind.rawValue)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func label(for kind: LensKind) -> LocalizedStringKey {
        switch kind {
        case .wide: "lens.wide"
        case .normal: "lens.normal"
        case .close: "lens.close"
        }
    }
}

@MainActor func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
}
