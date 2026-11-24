// swift-tools-version: 6.0
// Spec 07b / Constitution VII: who may use what. Pure rules (quota, premium from purchases), tested on macOS;
// StoreKit and the Keychain stay in the app, which feeds these rules the facts.
import PackageDescription

let package = Package(
    name: "AccessKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "AccessKit", targets: ["AccessKit"])],
    targets: [
        .target(name: "AccessKit"),
        .testTarget(name: "AccessKitTests", dependencies: ["AccessKit"]),
    ]
)
