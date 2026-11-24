import CompositionKit
import CoreMotion
import Foundation

/// How far the phone looks down, for the example's shooting angle (spec 04 "telefon eğimi"). Device motion needs no
/// permission and nothing leaves the device. Nil in the simulator, which has no motion sensors.
@MainActor
final class PhoneMotion {
    private let manager = CMMotionManager()
    private(set) var downwardAngle: Double?

    func start() {
        #if DEBUG
        // UI tests: a fixed angle, so the simulator can show the hint.
        if let fixed = UserDefaults.standard.object(forKey: "UITestPhoneDownward") as? Double { downwardAngle = fixed; return }
        #endif
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 0.1
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let g = motion?.gravity else { return }
            MainActor.assumeIsolated {
                self?.downwardAngle = PhoneTilt.downwardAngle(gravityX: g.x, y: g.y, z: g.z)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
