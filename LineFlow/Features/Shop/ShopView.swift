import SwiftUI
import StoreKit
import PuzzleKit

/// The cosmetics shop and the in-app purchase catalogue.
///
/// Everything sold here is cosmetic or convenience: nothing on this screen
/// makes a board easier to solve, which is the line the game does not cross.
struct ShopView: View {

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var category: Cosmetic.Category = .palette
    @State private var isShowingPaywall = false
    @State private var paywallContext = PaywallView.Context.general

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Ink.card.opacity(0.35).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        cosmeticsSection
                        gemPacksSection
                        unlocksSection
                        legalFooter
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text("shop.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CounterPill(systemImage: "diamond.fill", value: "\(services.profile.gems)")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text("common.close"))
                }
            }
            .sheet(isPresented: $isShowingPaywall) { PaywallView(context: paywallContext) }
            .overlay(alignment: .bottom) { bannerView }
        }
    }

    // MARK: - Cosmetics

    private var cosmeticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("shop.category", selection: $category) {
                ForEach(Cosmetic.Category.allCases) { category in
                    Text(LocalizedStringKey(category.titleKey)).tag(category)
                }
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CosmeticCatalog.items(in: category)) { cosmetic in
                    CosmeticTile(
                        cosmetic: cosmetic,
                        availability: availability(for: cosmetic),
                        action: { handle(cosmetic) }
                    )
                }
            }
        }
    }

    private func availability(for cosmetic: Cosmetic) -> CosmeticTile.Availability {
        let entitlements = services.entitlements
        if services.isEquipped(cosmetic) && entitlements.canUse(cosmetic) { return .equipped }
        if entitlements.canUse(cosmetic) { return .owned }

        guard let reason = entitlements.lockReason(for: cosmetic) else { return .owned }
        switch reason {
        case .needsGems(let price):
            return .buyableWithGems(price: price, affordable: services.profile.gems >= price)
        case .needsStars(let stars):
            return .needsStars(stars, current: services.profile.totalStars)
        case .needsPurchase(let product):
            return .needsPurchase(services.store.displayPrice(for: product))
        case .needsPro:
            return .needsPro
        }
    }

    private func handle(_ cosmetic: Cosmetic) {
        let entitlements = services.entitlements
        if entitlements.canUse(cosmetic) {
            services.equip(cosmetic)
            return
        }
        guard let reason = entitlements.lockReason(for: cosmetic) else { return }
        switch reason {
        case .needsGems:
            services.buyWithGems(cosmetic)
        case .needsPurchase(let product):
            Task { await services.purchase(product) }
        case .needsPro:
            paywallContext = .cosmetic(cosmetic.id)
            isShowingPaywall = true
        case .needsStars:
            // Nothing to buy - the player has to play for it.
            break
        }
    }

    // MARK: - Gems

    private var gemPacksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("shop.section.gems")
                .font(.headline)
                .foregroundStyle(Ink.primary)
            Text("shop.section.gemsCaption")
                .font(.footnote)
                .foregroundStyle(Ink.secondary)

            ForEach(ProductCatalog.consumables) { product in
                productRow(
                    product,
                    icon: "diamond.fill",
                    tint: Ink.gold,
                    detail: String(
                        format: NSLocalizedString("shop.gemsAmount", comment: ""),
                        product.gemGrant
                    )
                )
            }

            if services.showsAds {
                Button {
                    Task { await services.watchRewarded(.gems) }
                } label: {
                    rowLabel(
                        icon: "play.rectangle.fill",
                        tint: Ink.accent,
                        title: NSLocalizedString("shop.watchForGems", comment: ""),
                        detail: String(
                            format: NSLocalizedString("shop.gemsAmount", comment: ""),
                            ProductCatalog.gemsPerRewardedAd
                        ),
                        trailing: NSLocalizedString("shop.free", comment: "")
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Unlocks

    private var unlocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("shop.section.unlocks")
                .font(.headline)
                .foregroundStyle(Ink.primary)

            if !services.entitlements.isPro {
                Button {
                    paywallContext = .general
                    isShowingPaywall = true
                } label: {
                    rowLabel(
                        icon: "crown.fill",
                        tint: Ink.pro,
                        title: NSLocalizedString("product.pro.monthly.name", comment: ""),
                        detail: NSLocalizedString("shop.proCaption", comment: ""),
                        trailing: services.store.subscriptionPriceLine(for: .proMonthly) ?? "—"
                    )
                }
                .buttonStyle(.plain)
            }

            ForEach(ProductCatalog.oneOffUnlocks) { product in
                productRow(
                    product,
                    icon: product == .removeAds ? "nosign" : "paintpalette.fill",
                    tint: product == .removeAds ? Ink.gold : Ink.accent,
                    detail: NSLocalizedString(product.descriptionKey, comment: "")
                )
            }
        }
    }

    private func productRow(
        _ product: StoreProductID,
        icon: String,
        tint: Color,
        detail: String
    ) -> some View {
        let owned = services.entitlements.purchasedProducts.contains(product)
            && product.kind == .nonConsumable
        return Button {
            Task { await services.purchase(product) }
        } label: {
            rowLabel(
                icon: icon,
                tint: tint,
                title: NSLocalizedString(product.nameKey, comment: ""),
                detail: detail,
                trailing: owned
                    ? NSLocalizedString("shop.owned", comment: "")
                    : (services.store.displayPrice(for: product) ?? "—")
            )
        }
        .buttonStyle(.plain)
        .disabled(owned || services.store.product(for: product) == nil)
    }

    private func rowLabel(
        icon: String,
        tint: Color,
        title: String,
        detail: String,
        trailing: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Ink.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(trailing)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Ink.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.card))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Ink.stroke, lineWidth: 1)
        )
    }

    // MARK: - Legal

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Button {
                Task { await services.restorePurchases() }
            } label: {
                Text("shop.restore")
                    .font(.subheadline.weight(.semibold))
            }
            .disabled(services.store.isRestoring)

            Text("shop.legal")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Ink.secondary)

            HStack(spacing: 18) {
                Link(destination: LegalLinks.termsOfUse) { Text("legal.terms").font(.caption2) }
                Link(destination: LegalLinks.privacyPolicy) { Text("legal.privacy").font(.caption2) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner = services.banner {
            Text(LocalizedStringKey(banner.messageKey))
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(bannerColor(banner.style)))
                .foregroundStyle(Color(hex: "#0B1018"))
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: banner.id) {
                    try? await Task.sleep(for: .seconds(2.5))
                    services.banner = nil
                }
        }
    }

    private func bannerColor(_ style: AppServices.Banner.Style) -> Color {
        switch style {
        case .success: Ink.accent
        case .info: Ink.gold
        case .failure: Ink.danger
        }
    }
}

/// One cosmetic in the shop grid.
struct CosmeticTile: View {

    enum Availability: Equatable {
        case equipped
        case owned
        case buyableWithGems(price: Int, affordable: Bool)
        case needsStars(Int, current: Int)
        case needsPurchase(String?)
        case needsPro
    }

    let cosmetic: Cosmetic
    let availability: Availability
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                swatch
                Text(LocalizedStringKey(cosmetic.nameKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                statusLabel
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.card))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(availability == .equipped ? Ink.accent : Ink.stroke,
                            lineWidth: availability == .equipped ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var isDisabled: Bool {
        switch availability {
        case .equipped: true
        case .needsStars: true
        case .buyableWithGems(_, let affordable): !affordable
        default: false
        }
    }

    private var swatch: some View {
        HStack(spacing: 4) {
            ForEach(Array(cosmetic.swatch.enumerated()), id: \.offset) { _, hex in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: hex))
                    .frame(height: 34)
            }
        }
        .overlay(alignment: .topTrailing) {
            if case .needsPro = availability {
                ProBadge().padding(4)
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch availability {
        case .equipped:
            Label("cosmetic.equipped", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Ink.accent)
        case .owned:
            Text("cosmetic.tapToEquip")
                .font(.caption)
                .foregroundStyle(Ink.secondary)
        case .buyableWithGems(let price, let affordable):
            Label("\(price)", systemImage: "diamond.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(affordable ? Ink.gold : Ink.secondary)
        case .needsStars(let required, let current):
            Label("\(current)/\(required)", systemImage: "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Ink.secondary)
        case .needsPurchase(let price):
            Text(price ?? "—")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Ink.accent)
        case .needsPro:
            Text("cosmetic.proOnly")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Ink.pro)
        }
    }
}
