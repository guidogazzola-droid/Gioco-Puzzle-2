import SwiftUI
import StoreKit
import PuzzleKit

/// The Fieldweave Pro paywall.
///
/// Built on `SubscriptionStoreView` so Apple's own control renders the price,
/// the renewal period and the introductory offer for the shopper's storefront -
/// getting any of those wrong by hand is a guideline 3.1.2 rejection. The
/// one-off "remove ads" purchase sits underneath on purpose: a player who only
/// wants the ads gone should not have to take a subscription to get there.
///
/// The control is only shown once the subscription group has actually loaded.
/// Handed an empty group it draws its own untranslated "Subscription
/// Unavailable" placeholder - so the empty case gets a state of our own
/// instead.
///
/// It also brings its own dismiss control, in both states, so ours is added
/// only when we are the ones drawing the screen. Two crosses stacked down the
/// corner is what shipped before a review screenshot caught it.
struct PaywallView: View {

    enum Context: Hashable {
        case general
        case proTrack
        case removeAds
        case hints
        case cosmetic(String)

        var headlineKey: LocalizedStringKey {
            switch self {
            case .general: "paywall.headline.general"
            case .proTrack: "paywall.headline.proTrack"
            case .removeAds: "paywall.headline.removeAds"
            case .hints: "paywall.headline.hints"
            case .cosmetic: "paywall.headline.cosmetic"
            }
        }
    }

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    let context: Context

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    // Only when we are drawing the screen ourselves.
                    // SubscriptionStoreView brings its own dismiss control, and
                    // adding a second one stacks two crosses down the corner -
                    // which is exactly what shipped until a review screenshot
                    // caught it.
                    if !services.store.hasSubscriptionProducts {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { dismiss() } label: { Image(systemName: "xmark") }
                                .accessibilityLabel(Text("common.close"))
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) { alternativesFooter }
                .task {
                    // The catalogue is normally loaded at launch; this covers
                    // the paywall being reached before that finished, or after
                    // it failed.
                    let store = services.store
                    if !store.hasLoadedCatalogue && !store.isLoadingProducts {
                        await store.loadProducts()
                    }
                }
                .onChange(of: services.entitlements.isPro) { _, isPro in
                    // Close as soon as the purchase lands, and drop anything the
                    // player is no longer entitled to if it went the other way.
                    services.reconcileEquippedCosmetics()
                    if isPro { dismiss() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if services.store.hasSubscriptionProducts {
            subscriptionStore
        } else if services.store.hasLoadedCatalogue && !services.store.isLoadingProducts {
            unavailable
        } else {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var subscriptionStore: some View {
        SubscriptionStoreView(groupID: ProductCatalog.subscriptionGroupID) {
            marketingContent
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .redeemCode)
        .subscriptionStorePolicyDestination(url: LegalLinks.termsOfUse, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: LegalLinks.privacyPolicy, for: .privacyPolicy)
    }

    // MARK: - Nothing to sell

    /// Shown when the store answered without the subscription in it. Says the
    /// one thing a player needs to hear - this is not your fault and you have
    /// not lost anything - and offers the only useful action.
    private var unavailable: some View {
        VStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("paywall.unavailable.title")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("paywall.unavailable.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await services.store.refresh() }
            } label: {
                Text("paywall.unavailable.retry")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(services.store.isLoadingProducts)
            .padding(.top, 4)

            Button {
                Task { await services.restorePurchases() }
            } label: {
                Text("shop.restore")
                    .font(.footnote)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            catalogueReport
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    /// Debug builds only. "Subscription Unavailable" names neither the cause
    /// nor the fix; the count and the group being asked for name both.
    @ViewBuilder
    private var catalogueReport: some View {
        #if DEBUG
        let loaded = services.store.products.count
        let total = ProductCatalog.allIdentifiers.count
        VStack(spacing: 4) {
            Text(verbatim: "\(loaded)/\(total) products · group \(ProductCatalog.subscriptionGroupID)")
            if loaded == 0 {
                Text(verbatim: "Nothing loaded. Scheme ▸ Run ▸ Options ▸ StoreKit Configuration, and launch from Xcode.")
                    .multilineTextAlignment(.center)
            }
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.tertiary)
        .padding(.top, 28)
        #endif
    }

    // MARK: - Marketing

    private var marketingContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(Ink.pro)
                .padding(.top, 12)

            Text("paywall.title")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            Text(context.headlineKey)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                benefit("wave.3.right.circle.fill", "paywall.benefit.proTrack")
                benefit("nosign", "paywall.benefit.noAds")
                benefit("paintpalette.fill", "paywall.benefit.skins")
                benefit("lightbulb.fill", "paywall.benefit.hints")
                benefit("diamond.fill", "paywall.benefit.gems")
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
    }

    private func benefit(_ icon: String, _ key: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Ink.pro)
                .frame(width: 24)
            Text(key)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Alternatives

    /// Absent unless the purchase is both relevant and buyable. Offering a row
    /// with a dash where the price should be teaches the player that the shop
    /// is broken.
    @ViewBuilder
    private var alternativesFooter: some View {
        if !services.entitlements.hasRemoveAdsPurchase,
           !services.entitlements.isPro,
           let price = services.store.displayPrice(for: .removeAds) {
            VStack(spacing: 8) {
                Divider()
                Text("paywall.orJustRemoveAds")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await services.purchase(.removeAds) }
                } label: {
                    HStack {
                        Text("product.removeads.name")
                        Spacer()
                        Text(price)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.thinMaterial)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(.bar)
        }
    }
}
