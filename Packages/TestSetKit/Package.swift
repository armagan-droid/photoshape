// swift-tools-version: 6.0
// Spec 00 — labeled test set tooling. macOS only; never linked into the app (FR-006).
import PackageDescription

let package = Package(
    name: "TestSetKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TestSetKit", targets: ["TestSetKit"]),
        .executable(name: "testset", targets: ["testset"]),
        .executable(name: "testset-labeler", targets: ["testset-labeler"]),
    ],
    targets: [
        .target(name: "TestSetKit"),
        .executableTarget(name: "testset", dependencies: ["TestSetKit"]),
        .executableTarget(name: "testset-labeler", dependencies: ["TestSetKit"]),
        .testTarget(name: "TestSetKitTests", dependencies: ["TestSetKit"]),
    ]
)
