import Foundation

/// Lets one capture run at a time. Presses while a capture is in flight are dropped, never queued,
/// so rapid tapping cannot pile up work (spec 01 uç durum "art arda basma", SC-004).
public struct ShutterGate: Sendable {
    /// A capture that never reports back releases the gate after this many seconds.
    public let timeout: TimeInterval
    private var startedAt: TimeInterval?

    public init(timeout: TimeInterval = 5) { self.timeout = timeout }

    public var isBusy: Bool { startedAt != nil }

    /// Returns true when the press should start a capture.
    public mutating func press(at now: TimeInterval) -> Bool {
        if let startedAt, now - startedAt < timeout { return false }
        startedAt = now
        return true
    }

    public mutating func finish() { startedAt = nil }
}
