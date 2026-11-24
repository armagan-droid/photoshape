import Foundation

/// Product identifiers (App Store Connect). Prices are never written here: StoreKit gives them (spec 07 FR-005).
public enum ProductID {
    public static let yearly = "com.armaganyaman.photoshape.premium.yearly"
    public static let lifetime = "com.armaganyaman.photoshape.premium.lifetime"
    public static let premium: [String] = [yearly, lifetime]
    /// Photographer packs (Hikâye 5): sold one by one, not part of the lifetime license.
    public static let packPrefix = "com.armaganyaman.photoshape.pack."
}

/// What the app knows about one purchase, as StoreKit's verified transaction says (spec 07 FR-002).
public struct PurchaseRecord: Codable, Sendable, Hashable {
    public var productID: String
    public var purchaseDate: Date
    /// Subscriptions only.
    public var expirationDate: Date?
    /// Refunded or revoked by Apple.
    public var revocationDate: Date?
    /// Came through Family Sharing.
    public var isFamilyShared: Bool

    public init(productID: String, purchaseDate: Date, expirationDate: Date? = nil, revocationDate: Date? = nil,
                isFamilyShared: Bool = false) {
        self.productID = productID; self.purchaseDate = purchaseDate; self.expirationDate = expirationDate
        self.revocationDate = revocationDate; self.isFamilyShared = isFamilyShared
    }

    func isActive(at now: Date) -> Bool {
        if let revoked = revocationDate, revoked <= now { return false }
        if let end = expirationDate { return now < end }
        return purchaseDate <= now
    }
}

/// Premium and owned packs at a moment, from the purchase records (spec 07 Hikâye 3, SC-005).
public struct AccessState: Sendable, Hashable {
    public var isPremium: Bool
    public var packs: Set<String>
    /// Both a running yearly subscription and the lifetime license: tell the user how to cancel (uç durum).
    public var hasRedundantSubscription: Bool

    public static let free = AccessState(isPremium: false, packs: [], hasRedundantSubscription: false)

    /// - Parameter familySharing: whether shared purchases count (open question 3; default on).
    public static func resolve(_ records: [PurchaseRecord], at now: Date, familySharing: Bool = true) -> AccessState {
        let active = records.filter { $0.isActive(at: now) && (familySharing || !$0.isFamilyShared) }
        let ids = Set(active.map(\.productID))
        let premium = !ids.isDisjoint(with: ProductID.premium)
        let packs = Set(ids.filter { $0.hasPrefix(ProductID.packPrefix) }.map { String($0.dropFirst(ProductID.packPrefix.count)) })
        return AccessState(isPremium: premium, packs: packs,
                           hasRedundantSubscription: ids.contains(ProductID.yearly) && ids.contains(ProductID.lifetime))
    }
}

/// Free users add at most `limit` examples in any `window` (spec 05 Hikâye 5.1: a rolling 7 days, not a calendar week).
/// Deleting an example does not give the slot back (Hikâye 6.1), so only the dates of additions are kept.
public struct ReferenceQuota: Sendable, Hashable {
    public var limit = 3
    public var window: TimeInterval = 7 * 24 * 3600

    public init(limit: Int = 3, window: TimeInterval = 7 * 24 * 3600) { self.limit = limit; self.window = window }

    public func remaining(additions: [Date], at now: Date) -> Int {
        max(0, limit - recent(additions, at: now).count)
    }

    /// When the next free slot opens, nil when one is free now (shown as "a new one in 3 days").
    public func nextSlot(additions: [Date], at now: Date) -> Date? {
        let recent = recent(additions, at: now).sorted()
        guard recent.count >= limit else { return nil }
        return recent[recent.count - limit].addingTimeInterval(window)
    }

    /// Only what still matters is kept in the Keychain.
    public func pruned(_ additions: [Date], at now: Date) -> [Date] { recent(additions, at: now).sorted() }

    func recent(_ additions: [Date], at now: Date) -> [Date] {
        additions.filter { $0 <= now && now.timeIntervalSince($0) < window }
    }

    /// May the user add one more example now? Premium always may (spec 07 Hikâye 3.2).
    public func mayAdd(additions: [Date], at now: Date, access: AccessState) -> Bool {
        access.isPremium || remaining(additions: additions, at: now) > 0
    }
}
