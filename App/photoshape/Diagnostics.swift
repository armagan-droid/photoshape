import Foundation

/// Developer-build diagnostics printed to the console (seen with `devicectl ... --console` or Xcode).
/// Compiled out of release builds; nothing leaves the device (Constitution I).
enum Diagnostics {
    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[photoshape] \(message())")
        #endif
    }
}
