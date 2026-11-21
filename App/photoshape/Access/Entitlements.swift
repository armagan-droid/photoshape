import Foundation
import LookKit

/// The single question "may the user use this?" (Constitution VII). Callers never check purchases themselves;
/// spec 07 replaces only the implementation behind this protocol.
protocol Entitlements: Sendable {
    func isAvailable(_ look: LookRecipe) -> Bool
}

/// MVP: everything is open (spec 03 Hikâye 5.1).
struct AllUnlocked: Entitlements {
    func isAvailable(_ look: LookRecipe) -> Bool { true }
}

#if DEBUG
/// Developer builds only: locks the looks named in the `LockedLooks` launch argument (comma separated),
/// to exercise the locked state before payments exist (Hikâye 5.2).
struct DebugLockedLooks: Entitlements {
    let locked: Set<String>
    func isAvailable(_ look: LookRecipe) -> Bool { !locked.contains(look.id) }
}
#endif

enum EntitlementsFactory {
    static func make() -> Entitlements {
        #if DEBUG
        if let ids = UserDefaults.standard.string(forKey: "LockedLooks"), !ids.isEmpty {
            return DebugLockedLooks(locked: Set(ids.split(separator: ",").map(String.init)))
        }
        #endif
        return AllUnlocked()
    }
}
