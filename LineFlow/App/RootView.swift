import SwiftUI

/// Chooses between onboarding and the game, and hosts anything that must sit
/// above every screen - the launch splash and the ad presenter.
struct RootView: View {

    @Environment(AppServices.self) private var services

    /// Set when a house advertisement for Pro is tapped through. The paywall
    /// is presented from here because this is where the advertisement lives -
    /// its own sheet would go away with it.
    @State private var isShowingPaywallFromAd = false

    /// Once per launch, not once per foreground: this is @State on the root
    /// view, which WindowGroup builds when the process starts and keeps. A
    /// splash on every return from the background would be an insult.
    @State private var isLaunching = true

    var body: some View {
        ZStack {
            if services.profile.onboardingComplete {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }

            if let presentation = services.ads.presentation {
                HouseAdView(presentation: presentation) { completed in
                    services.ads.finish(completed: completed)
                } onOpenPaywall: {
                    isShowingPaywallFromAd = true
                }
                .transition(.opacity)
                .zIndex(10)
            }

            if isLaunching {
                SplashView { isLaunching = false }
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: services.profile.onboardingComplete)
        .animation(.easeInOut(duration: 0.2), value: services.ads.presentation)
        .animation(.easeInOut(duration: 0.35), value: isLaunching)
        .sheet(isPresented: $isShowingPaywallFromAd) {
            PaywallView(context: .removeAds)
        }
        .preferredColorScheme(.dark)
        .tint(Ink.accent)
    }
}
