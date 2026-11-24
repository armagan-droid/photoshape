import SwiftUI

/// Large view of the last photo with the system share sheet (Hikâye 4).
struct ReviewView: View {
    let capture: CameraModel.LastCapture
    /// "Diğer kareler" (spec 06 Hikâye 3): add another frame of the series as a new photo.
    var chooseAlternative: (Int) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlternatives = false
    @State private var hint = RevertHint()
    @State private var choosingInstagram = false
    @State private var fallbackShare = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)
                if let image = UIImage(contentsOfFile: capture.shareURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .accessibilityIdentifier("reviewImage")
                }
                if hint.isVisible {
                    Text("review.revertHint")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                        .accessibilityIdentifier("revertHint")
                }
                Spacer(minLength: 0)
                if !capture.alternativeThumbnails.isEmpty {
                    Button { showingAlternatives = true } label: {
                        Label("review.otherFrames", systemImage: "square.stack.3d.down.right").font(.subheadline)
                    }
                    .accessibilityIdentifier("otherFrames")
                    .padding(.bottom, 10)
                }
                if InstagramShare.isInstalled { instagramButton }
                ShareLink(item: capture.shareURL,
                          preview: SharePreview(Text("share.previewTitle"), image: Image(uiImage: capture.thumbnail))) {
                    Label("share.button", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: Capsule())
                        .foregroundStyle(.black)
                }
                .accessibilityIdentifier("share")
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }.accessibilityIdentifier("close")
                }
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("share.instagram", isPresented: $choosingInstagram, titleVisibility: .hidden) {
            Button("share.instagram.post") { Task { await share { await InstagramShare.sharePost(assetID: capture.assetID) } } }
                .accessibilityIdentifier("instagram.post")
            if InstagramShare.canShareStory {
                Button("share.instagram.story") { Task { await share { await InstagramShare.shareStory(photoAt: capture.shareURL) } } }
                    .accessibilityIdentifier("instagram.story")
            }
        }
        .sheet(isPresented: $showingAlternatives) { alternatives }
        .sheet(isPresented: $fallbackShare) {
            ActivitySheet(items: [capture.shareURL]).presentationDetents([.medium, .large])
        }
        .onAppear { hint.evaluate(revertible: capture.revertible) }
        .onChange(of: capture.revertible) { _, revertible in hint.evaluate(revertible: revertible) }
    }
}

extension ReviewView {
    var alternatives: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("review.otherFrames.hint").font(.footnote).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(Array(capture.alternativeThumbnails.enumerated()), id: \.offset) { index, image in
                        Button {
                            showingAlternatives = false
                            chooseAlternative(index)
                        } label: {
                            Image(uiImage: image).resizable().aspectRatio(4.0 / 5.0, contentMode: .fill)
                                .frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityIdentifier("otherFrame")
                    }
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle(Text("review.otherFrames"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.close") { showingAlternatives = false } } }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    /// Two taps to Instagram's post screen (spec 07 SC-001): this button, then "Post".
    var instagramButton: some View {
        Button { choosingInstagram = true } label: {
            Label("share.instagram", systemImage: "camera.circle")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: [.purple, .pink, .orange], startPoint: .leading, endPoint: .trailing), in: Capsule())
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier("instagram")
        .padding(.horizontal, 32)
        .padding(.bottom, 8)
    }

    /// Instagram's way first; the system share sheet when it does not work (Hikâye 1.5).
    func share(_ attempt: () async -> Bool) async {
        if await !attempt() { fallbackShare = true }
    }
}

/// Tells the user, on their first few photos, that the full frame is kept and can be restored in Photos
/// (spec 01 Hikâye 4.3, FR-012). Decided once per review; only for photos that really are revertible.
struct RevertHint {
    static let key = "revertHintShownCount"
    static let limit = 3
    private var decided = false
    private(set) var isVisible = false

    mutating func evaluate(revertible: Bool, defaults: UserDefaults = .standard) {
        guard !decided, revertible else { return }
        decided = true
        let shown = defaults.integer(forKey: Self.key)
        guard shown < Self.limit else { return }
        defaults.set(shown + 1, forKey: Self.key)
        isVisible = true
    }
}

/// Shown instead of a black screen when camera access was declined (Hikâye 5.2).
struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(.white.opacity(0.8))
            Text("camera.denied.title").font(.title3.bold()).foregroundStyle(.white)
            Text("camera.denied.body").multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
            Button("common.openSettings", action: openSettings)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("openSettings")
        }
        .padding(32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cameraDenied")
    }
}
