import CompositionKit
import CoreMotion
import Foundation

/// How far the phone looks down, for the example's shooting angle (spec 04 "telefon eğimi"). Device motion needs no
/// permission and nothing leaves the device. Nil in the simulator, which has no motion sensors.
@MainActor
final class PhoneMotion {
    private let manager = CMMotionManager()
    private(set) var downwardAngle: Double?
    /// How fast the phone is turning (rad/s): a moving phone gets a series (spec 06 Hikâye 4).
    private(set) var rotationRate = 0.0

    func start() {
        #if DEBUG
        // UI tests: a fixed angle, so the simulator can show the hint.
        if let fixed = UserDefaults.standard.string(forKey: "UITestPhoneDownward").flatMap(Double.init) { downwardAngle = fixed; return }
        #endif
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 0.1
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let g = motion.gravity, r = motion.rotationRate
            MainActor.assumeIsolated {
                self?.downwardAngle = PhoneTilt.downwardAngle(gravityX: g.x, y: g.y, z: g.z)
                self?.rotationRate = (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot()
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
