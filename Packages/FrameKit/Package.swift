// swift-tools-version: 6.0
// Shared camera/analysis boundary (docs/ortak-kamera-paketi.md). Must not depend on anything photoshape-specific
// (recipes, looks, Instagram) so it can move to a shared package unchanged.
import PackageDescription

let package = Package(
    name: "FrameKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "FrameKit", targets: ["FrameKit"])],
    targets: [
        .target(name: "FrameKit"),
        .testTarget(name: "FrameKitTests", dependencies: ["FrameKit"]),
    ]
)
