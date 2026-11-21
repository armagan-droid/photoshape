import SwiftUI

@main
struct PhotoshapeApp: App {
    @State private var camera = CameraModel(backend: makeCameraBackend(), looks: LookSelection(),
                                            entitlements: EntitlementsFactory.make())

    var body: some Scene {
        WindowGroup {
            CameraScreen(model: camera)
        }
    }
}

/// The real camera on a device; a generated scene in the simulator (no camera there).
@MainActor
private func makeCameraBackend() -> CameraBackend {
    #if targetEnvironment(simulator)
    SimulatedCameraBackend()
    #else
    AVCameraBackend()
    #endif
}
