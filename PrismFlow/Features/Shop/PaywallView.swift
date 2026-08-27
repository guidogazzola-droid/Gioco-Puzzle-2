import SwiftUI
import StoreKit
import PuzzleKit

/// The Prism Flow Pro paywall.
///
/// Built on `SubscriptionStoreView` so Apple's own control renders the price,
/// the renewal period and the introductory offer for the shopper's storefront -
/// getting any of those wrong by hand is a guideline 3.1.2 rejection. The
/// one-off "remove ads" purchase sits underneath on purpose: a player who only
/// wants the ads gone should not have to take a subscription to get there.
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
            SubscriptionStoreView(groupID: ProductCatalog.subscriptionGroupID) {
                marketingContent
            }
            .subscriptionStoreControlStyle(.prominentPicker)
            .subscriptionStoreButtonLabel(.multiline)
            .storeButton(.visible, for: .restorePurchases)
            .storeButton(.visible, for: .redeemCode)
            .subscriptionStorePolicyDestination(url: LegalLinks.termsOfUse, for: .termsOfService)
            .subscriptionStorePolicyDestination(url: LegalLinks.privacyPolicy, for: .privacyPolicy)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text("common.close"))
                }
            }
            .safeAreaInset(edge: .bottom) { alternativesFooter }
            .onChange(of: services.entitlements.isPro) { _, isPro in
                // Close as soon as the purchase lands, and drop anything the
                // player is no longer entitled to if it went the other way.
                services.reconcileEquippedCosmetics()
                if isPro { dismiss() }
            }
        }
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
                benefit("square.grid.3x3.fill", "paywall.benefit.proTrack")
                benefit("nosign", "paywall.benefit.noAds")
                benefit("paintpalette.fill", "paywall.benefit.skins")
                benefit("sparkles", "paywall.benefit.drops")
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

    @ViewBuilder
    private var alternativesFooter: some View {
        if !services.entitlements.hasRemoveAdsPurchase && !services.entitlements.isPro {
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
                        Text(services.store.displayPrice(for: .removeAds) ?? "—")
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
                .disabled(services.store.product(for: .removeAds) == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(.bar)
        }
    }
}
