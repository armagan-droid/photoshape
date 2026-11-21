import CaptureKit
import SwiftUI

struct CameraScreen: View {
    @Bindable var model: CameraModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.access {
            case .unknown: EmptyView()
            case .denied: PermissionDeniedView()
            case .authorized: camera
            }
        }
        .preferredColorScheme(.dark)
        .task { await model.activate() }
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

    private var camera: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            preview
            LensPicker(options: model.lensOptions, selected: model.selectedLens, select: model.select)
            controls
            Spacer(minLength: 0)
        }
        .overlay(alignment: .top) { noticeBanner }
    }

    private var preview: some View {
        CameraPreview(session: model.backend.previewSession, stillImage: model.backend.stillPreview) { view, device in
            model.tapToFocus(viewPoint: view, devicePoint: device)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .overlay { FrameMask().allowsHitTesting(false) }
        .overlay { focusMarker.allowsHitTesting(false) }
        .overlay { Color.white.opacity(flash ? 0.8 : 0).allowsHitTesting(false) }
        .clipped()
        .onChange(of: model.shutterCount) {
            flash = true
            withAnimation(.easeOut(duration: 0.25)) { flash = false }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.shutterCount)
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
            ShutterButton(action: model.shutter)
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

/// Dims everything outside the 4:5 output frame so the user sees what will be cropped (Hikâye 1.1).
/// Uses the same geometry as the saved crop (FR-002).
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                Circle().fill(.white).frame(width: 62, height: 62)
            }
        }
        .buttonStyle(ShutterPressStyle())
        .accessibilityLabel(Text("camera.shutter"))
        .accessibilityIdentifier("shutter")
    }
}

private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}

struct LensPicker: View {
    let options: [LensOption]
    let selected: LensKind
    let select: (LensOption) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.kind) { option in
                let isSelected = option.kind == selected
                Button { select(option) } label: {
                    Text(label(for: option.kind))
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.yellow : .white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(.white.opacity(isSelected ? 0.18 : 0.08)))
                }
                .accessibilityIdentifier("lens.\(option.kind.rawValue)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(height: 36)
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
