import Foundation

/// One instruction to the user (docs/ortak-kamera-paketi.md). Shared with GymSpot: nothing photoshape-specific.
public struct GuidanceInstruction: Sendable, Hashable {
    public enum Direction: String, Sendable, Hashable {
        case left, right, up, down, closer, farther
    }

    /// Stable code, e.g. "frame.closer" or "pose.leftArm.up". New kinds are added as data.
    public var kind: String
    public var direction: Direction?
    /// Lower is more important.
    public var priority: Int
    /// Localization key of the short sentence shown with it.
    public var phraseKey: String

    public init(kind: String, direction: Direction? = nil, priority: Int, phraseKey: String) {
        self.kind = kind; self.direction = direction; self.priority = priority; self.phraseKey = phraseKey
    }
}

/// Decides what is actually on screen from a stream of raw candidates (spec 04 FR-008, FR-K4):
/// one instruction at a time, shown at least `minimumDisplay`, no flicker at threshold values,
/// and no nagging: an instruction that stays unresolved for `nagLimit` is hidden for `quietPeriod`.
/// Time is passed in, so the rules are tested with a simulated clock.
public struct GuidanceStabilizer: Sendable {
    public var minimumDisplay: TimeInterval = 1.0
    /// A change (to another instruction or to "ready") must persist this long before it is shown.
    public var settle: TimeInterval = 0.35
    public var nagLimit: TimeInterval = 8
    public var quietPeriod: TimeInterval = 20

    public private(set) var shown: GuidanceInstruction?
    private var shownSince: TimeInterval = -.infinity
    private var pending: GuidanceInstruction?
    private var pendingSince: TimeInterval = 0
    private var pendingIsSet = false
    private var quietUntil: [String: TimeInterval] = [:]

    public init() {}

    /// Feed the latest raw candidate (nil = nothing to correct). Returns what should be displayed.
    @discardableResult
    public mutating func update(candidate raw: GuidanceInstruction?, at now: TimeInterval) -> GuidanceInstruction? {
        var candidate = raw
        if let c = candidate, let until = quietUntil[c.kind], now < until { candidate = nil }

        if candidate == shown {
            pendingIsSet = false
            if let s = shown, now - shownSince >= nagLimit {
                quietUntil[s.kind] = now + quietPeriod
                shown = nil
                shownSince = now
            }
            return shown
        }

        // Something different is wanted. Wait until it has settled.
        if !pendingIsSet || pending != candidate {
            pending = candidate
            pendingSince = now
            pendingIsSet = true
            return shown
        }
        guard now - pendingSince >= settle else { return shown }
        // Never cut an instruction short.
        if shown != nil, now - shownSince < minimumDisplay { return shown }
        shown = candidate
        shownSince = now
        pendingIsSet = false
        return shown
    }
}
