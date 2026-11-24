import CaptureKit
import SwiftUI
import UIKit

/// One-tap Instagram (spec 07 Hikâye 1, FR-001), through the ways Instagram opens to other apps:
/// Feed: the photo saved in the library, opened by its identifier; Story: the composed 9:16 image on the pasteboard.
/// Every failure returns false so the caller can fall back to the system share sheet (1.5); no error is shown.
@MainActor
enum InstagramShare {
    static var isInstalled: Bool {
        #if DEBUG
        if let forced = UserDefaults.standard.string(forKey: "UITestInstagramInstalled") { return forced.uppercased() == "YES" }
        #endif
        return URL(string: "instagram://app").map(UIApplication.shared.canOpenURL) ?? false
    }

    /// Meta requires an app ID for Stories (Config/Base.xcconfig `FACEBOOK_APP_ID`). Without one, no Story option.
    static var storyAppID: String? {
        let id = (Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String)?.trimmingCharacters(in: .whitespaces)
        return id?.isEmpty == false ? id : nil
    }

    static var canShareStory: Bool { isInstalled && storyAppID != nil }

    static func sharePost(assetID: String?) async -> Bool {
        guard let assetID, let encoded = assetID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "instagram://library?LocalIdentifier=\(encoded)") else { return false }
        return await open(url)
    }

    static func shareStory(photoAt fileURL: URL) async -> Bool {
        guard let appID = storyAppID,
              let url = URL(string: "instagram-stories://share?source_application=\(appID)"),
              let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let photo = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }
        let story = await Task.detached(priority: .userInitiated) { StoryComposer.compose(photo) }.value
        guard let story, let data = UIImage(cgImage: story).jpegData(compressionQuality: 0.92) else { return false }
        UIPasteboard.general.setItems([["com.instagram.sharedSticker.backgroundImage": data]],
                                      options: [.expirationDate: Date().addingTimeInterval(300), .localOnly: true])
        return await open(url)
    }

    private static func open(_ url: URL) async -> Bool {
        guard UIApplication.shared.canOpenURL(url) else { return false }
        return await UIApplication.shared.open(url)
    }
}

/// The system share sheet as a fallback when Instagram's way does not work.
struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
