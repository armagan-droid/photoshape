import Foundation

/// The single question "may the user use this?" (Constitution VII). Callers never check purchases themselves;
/// spec 07 replaces only the implementation behind this protocol.
protocol Entitlements: Sendable {
    func isAvailable(_ feature: Feature) -> Bool
}

enum Feature: Sendable {
    /// Shooting with an example photo (spec 05). Free in the MVP; v2 adds the weekly quota (spec 07).
    case exampleMatching
    /// The card's short summary written by the on-device model (spec 05 Hikâye 9). Free (open question 14).
    case exampleSummary
}

/// MVP: everything is open.
struct AllUnlocked: Entitlements {
    func isAvailable(_ feature: Feature) -> Bool { true }
}
