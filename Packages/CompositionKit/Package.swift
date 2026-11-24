// swift-tools-version: 6.0
// Spec 04 brain: compares the live subject (person pose or object) with the example and picks one instruction.
// Spec 05 Hikâye 7: reads the example (light, tone, color, angle, subject) for the "how was this shot" card.
// Uses Vision for detection; comparison is pure and tested on macOS (Constitution IV).
import PackageDescription

let package = Package(
    name: "CompositionKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "CompositionKit", targets: ["CompositionKit"])],
    dependencies: [
        .package(path: "../FrameKit"),
        .package(path: "../LookKit"),
        // Test-only: measuring SC-007..SC-010 on the labeled set. Never linked into the app.
        .package(path: "../TestSetKit"),
    ],
    targets: [
        .target(name: "CompositionKit", dependencies: ["FrameKit", "LookKit"]),
        .testTarget(name: "CompositionKitTests", dependencies: [
            "CompositionKit",
            .product(name: "TestSetKit", package: "TestSetKit", condition: .when(platforms: [.macOS])),
        ]),
    ]
)
