import AccessKit
import Foundation
import Security
import StoreKit

/// Access from StoreKit 2 (spec 07 FR-002, FR-003): Apple's signed transactions, verified on the device; no server
/// of ours (Constitution I). Works offline: StoreKit keeps the verified entitlements on the device (Hikâye 3.3).
@MainActor @Observable
final class StoreEntitlements: Entitlements {
    private(set) var access = AccessState.free
    /// Yearly first, then lifetime; empty until StoreKit answers.
    private(set) var products: [Product] = []
    private(set) var isPurchasing = false
    /// Waiting for approval (Ask to Buy) — shown as "waiting" (uç durum).
    private(set) var isPending = false
    private(set) var productsFailed = false
    private var additions: [Date]
    private let quota = ReferenceQuota()
    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        additions = QuotaKeychain.load()
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "ResetQuota") { additions = []; QuotaKeychain.save([]) }
        if let used = UserDefaults.standard.string(forKey: "UITestQuotaUsed").flatMap(Int.init) {
            additions = (0..<used).map { Date().addingTimeInterval(-Double($0 + 1) * 3600) }
            QuotaKeychain.save(additions)
        }
        #endif
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh(); await loadProducts() }
    }

    // MARK: - Entitlements

    func isAvailable(_ feature: Feature) -> Bool {
        switch feature {
        case .exampleMatching, .exampleSummary: true
        case .addExample: quota.mayAdd(additions: additions, at: Date(), access: access)
        }
    }

    func didUse(_ feature: Feature) {
        guard feature == .addExample, !access.isPremium else { return }
        let now = Date()
        additions = quota.pruned(additions + [now], at: now)
        QuotaKeychain.save(additions)
    }

    var remainingExamples: Int { quota.remaining(additions: additions, at: Date()) }
    var nextExampleSlot: Date? { quota.nextSlot(additions: additions, at: Date()) }

    // MARK: - StoreKit

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductID.premium)
            products = loaded.sorted { a, _ in a.id == ProductID.yearly }
            productsFailed = loaded.isEmpty
        } catch {
            productsFailed = true
            Diagnostics.log("store: products failed \(error)")
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                if case .verified(let transaction) = result { await transaction.finish() }
                isPending = false
                await refresh()
            case .pending: isPending = true
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            Diagnostics.log("store: purchase failed \(error)")
        }
    }

    /// "Satın alımları geri yükle" (Hikâye 3.4).
    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    func refresh() async {
        var records: [PurchaseRecord] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result else { continue }
            records.append(PurchaseRecord(productID: t.productID, purchaseDate: t.purchaseDate, expirationDate: t.expirationDate,
                                          revocationDate: t.revocationDate, isFamilyShared: t.ownershipType == .familyShared))
        }
        let state = AccessState.resolve(records, at: Date())
        if state != access { access = state; Diagnostics.log("store: premium \(state.isPremium)") }
    }
}

/// Dates of examples added, kept in the Keychain so reinstalling does not reset the quota (spec 05 Hikâye 5.1).
/// Only dates; nothing about the photos.
enum QuotaKeychain {
    private static var query: [CFString: Any] { [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "photoshape.referenceQuota",
        kSecAttrAccount: "additions",
    ] }

    static func load() -> [Date] {
        var q = query
        q[kSecReturnData] = true
        q[kSecMatchLimit] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data,
              let seconds = try? JSONDecoder().decode([Double].self, from: data) else { return [] }
        return seconds.map(Date.init(timeIntervalSince1970:))
    }

    static func save(_ dates: [Date]) {
        guard let data = try? JSONEncoder().encode(dates.map(\.timeIntervalSince1970)) else { return }
        let attributes: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }
}
