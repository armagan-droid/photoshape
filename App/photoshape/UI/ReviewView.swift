import SwiftUI

/// Large view of the last photo with the system share sheet (Hikâye 4).
struct ReviewView: View {
    let capture: CameraModel.LastCapture
    @Environment(\.dismiss) private var dismiss

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
                Spacer(minLength: 0)
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
