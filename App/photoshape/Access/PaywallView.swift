import AccessKit
import StoreKit
import SwiftUI

/// Opens when a free user tries to add a fourth example in 7 days (spec 05 Hikâye 5.2, spec 07 Hikâye 2.3, 3).
/// Lifetime is as prominent as yearly: "no subscription needed" (FR-007). Closing it always returns to the camera
/// with the examples already added (FR-010).
struct PaywallView: View {
    let store: StoreEntitlements
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "photo.stack").font(.system(size: 44)).foregroundStyle(.yellow)
                    Text("paywall.title").font(.title2.bold())
                    Text("paywall.body").foregroundStyle(.secondary)
                    if let next = store.nextExampleSlot {
                        (Text("paywall.nextSlot") + Text(" ") + Text(next, style: .relative))
                            .font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("paywall.nextSlot")
                    }
                    Label("paywall.noSubscription", systemImage: "checkmark.seal")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("paywall.noSubscription")

                    if store.products.isEmpty {
                        if store.productsFailed {
                            Button("paywall.retry") { Task { await store.loadProducts() } }
                        } else {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(store.products, id: \.id) { product in
                        ProductButton(product: product, isBusy: store.isPurchasing) {
                            Task { await store.purchase(product); if store.access.isPremium { dismiss() } }
                        }
                    }
                    if store.isPending {
                        Text("paywall.pending").font(.footnote).foregroundStyle(.orange)
                    }

                    Button("paywall.restore") { Task { await store.restore(); if store.access.isPremium { dismiss() } } }
                        .accessibilityIdentifier("paywall.restore")
                    Text("paywall.renewalTerms").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Link("paywall.terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        if let privacy = Self.privacyURL { Link("paywall.privacy", destination: privacy) }
                    }
                    .font(.caption)
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.close") { dismiss() }.accessibilityIdentifier("paywall.close") }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall")
        .onChange(of: store.access.isPremium) { _, premium in if premium { dismiss() } }
    }

    static var privacyURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "PhotoshapePrivacyPolicyURL") as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }
}

/// One product with its local price from StoreKit (FR-005); yearly says it renews, lifetime that it is paid once.
private struct ProductButton: View {
    let product: Product
    let isBusy: Bool
    let buy: () -> Void

    var body: some View {
        Button(action: buy) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.id == ProductID.lifetime ? "paywall.lifetime" : "paywall.yearly").font(.headline)
                    Text(product.id == ProductID.lifetime ? "paywall.lifetime.detail" : "paywall.yearly.detail")
                        .font(.caption).foregroundStyle(.black.opacity(0.6))
                }
                Spacer()
                Text(product.displayPrice).font(.headline.monospacedDigit())
            }
            .padding(14)
            .background(product.id == ProductID.lifetime ? Color.yellow : Color.white, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.black)
        }
        .disabled(isBusy)
        .accessibilityIdentifier("paywall.product.\(product.id == ProductID.lifetime ? "lifetime" : "yearly")")
    }
}
