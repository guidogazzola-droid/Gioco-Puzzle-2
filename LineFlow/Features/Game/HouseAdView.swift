import SwiftUI
import SafariServices
import PuzzleKit

/// The full-screen advertisement.
///
/// The mechanics are deliberately those of a real ad unit - a non-skippable
/// window, a close control that only appears once the window is up, a rewarded
/// unit that pays out only if watched to the end - because the pacing rules and
/// the "watch for a hint" flow have to behave the same on the day a network is
/// wired in. What changes then is what fills the window, not this timing.
struct HouseAdView: View {

    let presentation: AdPresentation
    /// Called when the unit is dismissed. `completed` is false if a rewarded
    /// unit was abandoned early, which forfeits the reward.
    let onFinish: (Bool) -> Void
    /// Called after `onFinish` when the player taps through to an
    /// advertisement whose destination is inside the app.
    let onOpenPaywall: () -> Void

    @State private var remaining: TimeInterval
    @State private var web: URL?

    init(
        presentation: AdPresentation,
        onFinish: @escaping (Bool) -> Void,
        onOpenPaywall: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.onFinish = onFinish
        self.onOpenPaywall = onOpenPaywall
        _remaining = State(initialValue: presentation.duration)
    }

    private var ad: HouseAd { presentation.ad }
    private var canClose: Bool { remaining <= 0 }

    private var dismissKey: LocalizedStringKey {
        presentation.isRewarded ? "ad.claim" : "common.close"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1B2230"), Color(hex: "#0B1018")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("ad.sponsorTag")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.12)))
                    .foregroundStyle(Ink.secondary)

                Image(systemName: ad.icon)
                    .font(.system(size: 54))
                    .foregroundStyle(ad.tint)

                Text(LocalizedStringKey(ad.titleKey))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.center)

                Text(LocalizedStringKey(ad.bodyKey))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Ink.secondary)
                    .padding(.horizontal, 36)

                Button { act() } label: {
                    Text(LocalizedStringKey(ad.ctaKey))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.top, 4)

                // Dismissal sits under the call to action, and only once the
                // window is up. A rewarded unit is abandoned with the X, which
                // forfeits the reward - the same bargain a network offers.
                if canClose {
                    Button { onFinish(true) } label: {
                        Text(dismissKey)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Ink.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(String(format: NSLocalizedString("ad.countdown", comment: ""), Int(remaining.rounded(.up))))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Ink.secondary)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if canClose || presentation.isRewarded {
                Button {
                    onFinish(canClose)
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(canClose ? Ink.primary : Ink.secondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
                .padding(20)
                .accessibilityLabel(Text("common.close"))
            }
        }
        // Presented over the unit rather than replacing it: the player comes
        // back to the advertisement, and from there to the game, which is what
        // a tap on a real interstitial does too.
        .sheet(item: $web) { SafariSheet(url: $0).ignoresSafeArea() }
        .task(id: presentation.id) {
            while remaining > 0 {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                remaining = max(0, remaining - 0.1)
            }
        }
    }

    private func act() {
        switch ad.destination {
        case .web(let url):
            web = url
        case .appStore(let id):
            // Not reachable today - no creative uses it yet - but the App Store
            // is a web destination too, so it degrades rather than doing
            // nothing if one ever does before SKStoreProductViewController is
            // wired up.
            web = URL(string: "https://apps.apple.com/app/id\(id)")
        case .paywall:
            // Dismissal semantics stay in one place: tapping through before
            // the window is up forfeits a rewarded unit, exactly as the X does.
            onFinish(canClose)
            onOpenPaywall()
        }
    }
}

/// `URL` is not `Identifiable`, and `sheet(item:)` needs it to be.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
