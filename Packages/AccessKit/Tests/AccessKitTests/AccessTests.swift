import Foundation
import Testing
@testable import AccessKit

let day: TimeInterval = 24 * 3600
let now = Date(timeIntervalSince1970: 1_800_000_000)

@Suite("Premium from purchases (spec 07 Hikâye 3, SC-005)")
struct AccessStateTests {
    @Test func nothingBoughtIsFree() {
        #expect(AccessState.resolve([], at: now) == .free)
    }

    @Test func runningYearlyIsPremiumUntilItEnds() {
        let yearly = PurchaseRecord(productID: ProductID.yearly, purchaseDate: now - 100 * day, expirationDate: now + 265 * day)
        #expect(AccessState.resolve([yearly], at: now).isPremium)
        // Hikâye 3.5: an ended subscription locks premium again.
        #expect(!AccessState.resolve([yearly], at: now + 266 * day).isPremium)
    }

    @Test func lifetimeNeverEnds() {
        let lifetime = PurchaseRecord(productID: ProductID.lifetime, purchaseDate: now - day)
        #expect(AccessState.resolve([lifetime], at: now + 3650 * day).isPremium)
    }

    @Test func refundEndsPremium() {
        let refunded = PurchaseRecord(productID: ProductID.lifetime, purchaseDate: now - 10 * day, revocationDate: now - day)
        #expect(!AccessState.resolve([refunded], at: now).isPremium)
        // Before the refund it was premium (photos taken then are not affected).
        #expect(AccessState.resolve([refunded], at: now - 5 * day).isPremium)
    }

    @Test func familySharingFollowsTheSetting() {
        let shared = PurchaseRecord(productID: ProductID.lifetime, purchaseDate: now - day, isFamilyShared: true)
        #expect(AccessState.resolve([shared], at: now).isPremium)
        #expect(!AccessState.resolve([shared], at: now, familySharing: false).isPremium)
    }

    @Test func packsAreOwnedSeparately() {
        let pack = PurchaseRecord(productID: ProductID.packPrefix + "istanbul-mornings", purchaseDate: now - day)
        let state = AccessState.resolve([pack], at: now)
        #expect(state.packs == ["istanbul-mornings"])
        #expect(!state.isPremium, "a pack is not premium, and lifetime does not include packs")
    }

    @Test func yearlyAndLifetimeTogetherIsFlagged() {
        let both = [PurchaseRecord(productID: ProductID.yearly, purchaseDate: now - day, expirationDate: now + 300 * day),
                    PurchaseRecord(productID: ProductID.lifetime, purchaseDate: now - day)]
        #expect(AccessState.resolve(both, at: now).hasRedundantSubscription)
    }

    @Test func futurePurchaseDoesNotCountYet() {
        #expect(!AccessState.resolve([PurchaseRecord(productID: ProductID.lifetime, purchaseDate: now + day)], at: now).isPremium)
    }
}

@Suite("Three examples in any 7 days (spec 05 Hikâye 5)")
struct QuotaTests {
    let quota = ReferenceQuota()

    @Test func threeThenStop() {
        let added = [now - 3 * day, now - 2 * day, now - day]
        #expect(quota.remaining(additions: [], at: now) == 3)
        #expect(quota.remaining(additions: Array(added.prefix(2)), at: now) == 1)
        #expect(quota.remaining(additions: added, at: now) == 0)
        #expect(!quota.mayAdd(additions: added, at: now, access: .free))
    }

    @Test func rollingWindowNotCalendarWeek() {
        let added = [now - 6.9 * day, now - 2 * day, now - day]
        #expect(quota.remaining(additions: added, at: now) == 0)
        #expect(quota.remaining(additions: added, at: now + 0.2 * day) == 1, "the oldest drops out after 7 days")
        #expect(quota.nextSlot(additions: added, at: now)! == now - 6.9 * day + 7 * day)
        #expect(quota.nextSlot(additions: [now - day], at: now) == nil)
    }

    @Test func premiumHasNoQuota() {
        let added = (0..<20).map { now - Double($0) * 3600 }
        let premium = AccessState(isPremium: true, packs: [], hasRedundantSubscription: false)
        #expect(quota.mayAdd(additions: added, at: now, access: premium))
    }

    @Test func pruningKeepsOnlyTheWindow() {
        let added = [now - 30 * day, now - 8 * day, now - day]
        #expect(quota.pruned(added, at: now) == [now - day])
    }
}
