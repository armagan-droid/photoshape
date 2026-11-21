// swift-tools-version: 6.0
// Spec 03 brain: look recipe format, color transform, renderer, catalog, color science.
// No camera, UIKit or SwiftUI; tested on macOS with `swift test` (Constitution IV).
import PackageDescription

let package = Package(
    name: "LookKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "LookKit", targets: ["LookKit"]),
        .executable(name: "look-tool", targets: ["look-tool"]),
    ],
    targets: [
        .target(name: "LookKit", resources: [.copy("Resources/Looks")]),
        .executableTarget(name: "look-tool", dependencies: ["LookKit"]),
        .testTarget(name: "LookKitTests", dependencies: ["LookKit"]),
    ]
)
