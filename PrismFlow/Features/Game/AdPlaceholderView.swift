import SwiftUI
import PuzzleKit

/// Stand-in for a real ad unit.
///
/// It deliberately behaves like one: a non-skippable window, a close control
/// that only appears when the window is up, and a rewarded unit that pays out
/// only if it is watched to the end. That means the pacing rules and the
/// "watch for a hint" flow can be exercised in the simulator without linking
/// an ad SDK. Replace this with the network's own presentation - the rest of
/// the game only knows about `AdService`.
struct AdPlaceholderView: View {

    let presentation: AdPresentation
    let onFinish: (Bool) -> Void

    @State private var remaining: TimeInterval

    init(presentation: AdPresentation, onFinish: @escaping (Bool) -> Void) {
        self.presentation = presentation
        self.onFinish = onFinish
        _remaining = State(initialValue: presentation.duration)
    }

    private var canClose: Bool { remaining <= 0 }

    private var titleKey: LocalizedStringKey {
        presentation.isRewarded ? "ad.rewardedTitle" : "ad.interstitialTitle"
    }

    private var closeKey: LocalizedStringKey {
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
                Text("ad.placeholderTag")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.12)))
                    .foregroundStyle(Ink.secondary)

                Image(systemName: presentation.isRewarded ? "gift.fill" : "megaphone.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Ink.accent)

                Text(titleKey)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Ink.primary)

                Text("ad.placeholderBody")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Ink.secondary)
                    .padding(.horizontal, 40)

                if canClose {
                    Button {
                        onFinish(true)
                    } label: {
                        Text(closeKey)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                } else {
                    Text(String(format: NSLocalizedString("ad.countdown", comment: ""), Int(remaining.rounded(.up))))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Ink.secondary)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            // A rewarded unit can always be abandoned - and doing so forfeits
            // the reward, exactly as a real network behaves. An interstitial
            // only becomes closable once its window is up.
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
        .task(id: presentation.id) {
            while remaining > 0 {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                remaining = max(0, remaining - 0.1)
            }
        }
    }
}
