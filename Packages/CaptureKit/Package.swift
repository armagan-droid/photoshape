// swift-tools-version: 6.0
// Pure capture logic of the app body (spec 01): crop geometry, lens catalog, shutter gate, edit record, 4:5 rendering.
// No AVFoundation session, UIKit or SwiftUI, so it is tested on macOS with `swift test` (Constitution IV).
import PackageDescription

let package = Package(
    name: "CaptureKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "CaptureKit", targets: ["CaptureKit"])],
    targets: [
        .target(name: "CaptureKit"),
        .testTarget(name: "CaptureKitTests", dependencies: ["CaptureKit"]),
    ]
)
