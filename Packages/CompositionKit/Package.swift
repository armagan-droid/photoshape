// swift-tools-version: 6.0
// Spec 04 brain: compares the live subject (person pose or object) with the example and picks one instruction.
// Uses Vision for detection; comparison is pure and tested on macOS (Constitution IV).
import PackageDescription

let package = Package(
    name: "CompositionKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "CompositionKit", targets: ["CompositionKit"])],
    dependencies: [.package(path: "../FrameKit")],
    targets: [
        .target(name: "CompositionKit", dependencies: ["FrameKit"]),
        .testTarget(name: "CompositionKitTests", dependencies: ["CompositionKit"]),
    ]
)
