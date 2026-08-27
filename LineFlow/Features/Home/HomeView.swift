import SwiftUI
import PuzzleKit

/// The hub: continue playing, the daily board, the Pro track, the shop.
struct HomeView: View {

    @Environment(AppServices.self) private var services

    @State private var route: Route? = nil
    @State private var isShowingShop = false
    @State private var isShowingSettings = false
    @State private var isShowingPaywall = false
    @State private var paywallContext = PaywallView.Context.general

    enum Route: Hashable {
        case campaign(LevelTrack)
        case daily
        case map(LevelTrack)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackdropView(
                    style: services.theme.background,
                    reduceMotionPreference: services.profile.settings.reduceMotion
                )

                ScrollView {
                    VStack(spacing: 18) {
                        header
                        continueCard
                        dailyCard
                        proCard
                        shopRow
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(item: $route) { route in
                destination(for: route)
            }
            .sheet(isPresented: $isShowingShop) { ShopView() }
            .sheet(isPresented: $isShowingSettings) { SettingsView() }
            .sheet(isPresented: $isShowingPaywall) { PaywallView(context: paywallContext) }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .campaign(let track):
            GameView(model: GameViewModel(
                mode: .campaign(track),
                level: services.profile.nextLevel(on: track),
                services: services
            ))
        case .daily:
            GameView(model: GameViewModel(mode: .daily, level: 0, services: services))
        case .map(let track):
            LevelMapView(track: track)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("app.name")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(Ink.primary)
                Text(String(
                    format: NSLocalizedString("home.starTotal", comment: ""),
                    services.profile.totalStars
                ))
                .font(.footnote)
                .foregroundStyle(Ink.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                CounterPill(systemImage: "diamond.fill", value: "\(services.profile.gems)")
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(Ink.secondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Ink.card))
                }
                .accessibilityLabel(Text("home.settings"))
            }
        }
        .padding(.top, 8)
    }

    private var continueCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("home.continue.title")
                    .font(.headline)
                    .foregroundStyle(Ink.primary)
                Text(String(
                    format: NSLocalizedString("home.continue.subtitle", comment: ""),
                    services.profile.nextLevel(on: .free),
                    NSLocalizedString(
                        ChapterCatalog.chapter(
                            containing: services.profile.nextLevel(on: .free),
                            track: .free
                        ).titleKey,
                        comment: ""
                    )
                ))
                .font(.subheadline)
                .foregroundStyle(Ink.secondary)

                Button {
                    route = .campaign(.free)
                } label: {
                    Text("home.continue.action")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    route = .map(.free)
                } label: {
                    Text("home.levels")
                }
                .buttonStyle(PrimaryButtonStyle(isProminent: false))
            }
        }
    }

    private var dailyCard: some View {
        Card {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("home.daily.title")
                            .font(.headline)
                            .foregroundStyle(Ink.primary)
                        if services.hasClearedTodaysDaily {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Ink.accent)
                        }
                    }
                    Text(streakText)
                        .font(.subheadline)
                        .foregroundStyle(Ink.secondary)
                }
                Spacer()
                let dailyActionKey: LocalizedStringKey = services.hasClearedTodaysDaily
                    ? "home.daily.replay" : "home.daily.play"
                Button {
                    route = .daily
                } label: {
                    Text(dailyActionKey)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Ink.accent))
                        .foregroundStyle(Color(hex: "#0B1018"))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var streakText: String {
        String(
            format: NSLocalizedString("home.daily.streak", comment: ""),
            services.profile.stats.currentStreak
        )
    }

    private var proSubtitleKey: LocalizedStringKey {
        services.canPlayProTrack ? "home.pro.subtitleActive" : "home.pro.subtitle"
    }

    private var proCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("home.pro.title")
                        .font(.headline)
                        .foregroundStyle(Ink.primary)
                    ProBadge()
                }
                Text(proSubtitleKey)
                    .font(.subheadline)
                    .foregroundStyle(Ink.secondary)

                if services.canPlayProTrack {
                    Button { route = .campaign(.pro) } label: { Text("home.pro.play") }
                        .buttonStyle(PrimaryButtonStyle(tint: Ink.pro))
                    Button { route = .map(.pro) } label: { Text("home.levels") }
                        .buttonStyle(PrimaryButtonStyle(isProminent: false))
                } else {
                    Button {
                        paywallContext = .proTrack
                        isShowingPaywall = true
                    } label: {
                        Text("home.pro.unlock")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Ink.pro))
                }
            }
        }
    }

    private var shopRow: some View {
        HStack(spacing: 14) {
            tile(icon: "paintpalette.fill", titleKey: "home.shop", tint: Ink.accent) {
                isShowingShop = true
            }
            if services.showsAds {
                tile(icon: "nosign", titleKey: "home.removeAds", tint: Ink.gold) {
                    paywallContext = .removeAds
                    isShowingPaywall = true
                }
            }
        }
    }

    private func tile(
        icon: String,
        titleKey: LocalizedStringKey,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                Text(titleKey)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Ink.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Ink.card))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Ink.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
