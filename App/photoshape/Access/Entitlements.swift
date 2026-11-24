import Foundation

/// The single question "may the user use this?" (Constitution VII). Callers never check purchases themselves;
/// spec 07 replaced only the implementation behind this protocol (`StoreEntitlements`).
@MainActor
protocol Entitlements {
    func isAvailable(_ feature: Feature) -> Bool
    /// A limited feature was used (the quota counts examples added).
    func didUse(_ feature: Feature)
}

extension Entitlements {
    func didUse(_ feature: Feature) {}
}

enum Feature: Sendable {
    /// Shooting with an example photo already added (spec 05). Never limited.
    case exampleMatching
    /// The card's short summary written by the on-device model (spec 05 Hikâye 9). Free (open question 14).
    case exampleSummary
    /// Adding a new example: free users 3 in any 7 days, premium unlimited (spec 05 Hikâye 5, spec 07).
    case addExample
}

/// v1 (MVP) and builds with the paywall turned off: everything is open.
struct AllUnlocked: Entitlements {
    func isAvailable(_ feature: Feature) -> Bool { true }
}

enum AppAccess {
    /// `PAYWALL_ENABLED` in Config/Base.xcconfig (v1: NO). Developer builds: `-Paywall YES|NO` overrides.
    static var paywallEnabled: Bool {
        #if DEBUG
        if let forced = UserDefaults.standard.string(forKey: "Paywall") { return forced.uppercased() == "YES" }
        #endif
        return (Bundle.main.object(forInfoDictionaryKey: "PhotoshapePaywall") as? String)?.uppercased() == "YES"
    }

    @MainActor static func make() -> Entitlements {
        paywallEnabled ? StoreEntitlements() : AllUnlocked()
    }
}
