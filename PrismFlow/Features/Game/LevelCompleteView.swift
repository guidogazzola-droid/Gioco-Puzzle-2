import SwiftUI
import PuzzleKit

/// The win overlay: what you scored, what you earned, where to go next.
struct LevelCompleteView: View {

    let completion: GameViewModel.Completion
    let isDaily: Bool
    let hasNextLevel: Bool
    let onNext: () -> Void
    let onReplay: () -> Void
    let onExit: () -> Void

    @State private var hasAppeared = false

    private var outcome: LevelOutcome { completion.outcome }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(headlineKey)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Ink.primary)

                StarRow(stars: outcome.stars, size: 34)
                    .scaleEffect(hasAppeared ? 1 : 0.6)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: hasAppeared)

                HStack(spacing: 14) {
                    statTile(
                        valueText: "\(outcome.moves)",
                        captionKey: "complete.moves",
                        detail: String(format: NSLocalizedString("complete.par", comment: ""), outcome.par)
                    )
                    statTile(
                        valueText: GameView.timeString(outcome.seconds),
                        captionKey: "complete.time"
                    )
                    statTile(
                        valueText: "+\(outcome.gems + completion.dailyBonus)",
                        captionKey: "complete.gems",
                        tint: Ink.gold
                    )
                }

                if isDaily && !completion.wasCounted {
                    Text("complete.dailyAlreadyClaimed")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Ink.secondary)
                }

                if outcome.hintsUsed > 0 {
                    Text("complete.hintUsed")
                        .font(.footnote)
                        .foregroundStyle(Ink.secondary)
                }

                VStack(spacing: 10) {
                    if hasNextLevel {
                        Button(action: onNext) {
                            Text("complete.next")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    HStack(spacing: 10) {
                        Button(action: onReplay) { Text("complete.replay") }
                            .buttonStyle(PrimaryButtonStyle(isProminent: false))
                        Button(action: onExit) { Text("complete.exit") }
                            .buttonStyle(PrimaryButtonStyle(isProminent: false))
                    }
                }
            }
            .padding(26)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Ink.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Ink.stroke, lineWidth: 1)
            )
            .padding(24)
        }
        .onAppear { hasAppeared = true }
    }

    private var headlineKey: LocalizedStringKey {
        if outcome.isPerfect { return "complete.perfect" }
        return outcome.stars == 2 ? "complete.good" : "complete.solved"
    }

    private func statTile(
        valueText: String,
        captionKey: LocalizedStringKey,
        detail: String? = nil,
        tint: Color = Ink.primary
    ) -> some View {
        VStack(spacing: 3) {
            Text(valueText)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
            Text(captionKey)
                .font(.caption2)
                .foregroundStyle(Ink.secondary)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Ink.secondary.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ink.cardRaised))
    }
}

/// Offered when the player wants a hint but has none left.
struct HintOptionsView: View {

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    let onWatchAd: () -> Void
    let onBuyWithGems: () -> Void
    let onSubscribe: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Ink.stroke).frame(width: 40, height: 4).padding(.top, 10)

            Text("hint.title")
                .font(.title3.weight(.bold))
                .foregroundStyle(Ink.primary)
            Text("hint.body")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                if services.showsAds {
                    Button {
                        dismiss()
                        onWatchAd()
                    } label: {
                        Label("hint.watchAd", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button {
                    dismiss()
                    onBuyWithGems()
                } label: {
                    Label(
                        String(
                            format: NSLocalizedString("hint.buyWithGems", comment: ""),
                            ProductCatalog.hintGemCost
                        ),
                        systemImage: "diamond.fill"
                    )
                }
                .buttonStyle(PrimaryButtonStyle(tint: Ink.gold))
                .disabled(services.profile.gems < ProductCatalog.hintGemCost)

                Button {
                    dismiss()
                    onSubscribe()
                } label: {
                    Label("hint.goPro", systemImage: "crown.fill")
                }
                .buttonStyle(PrimaryButtonStyle(isProminent: false))
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.card.ignoresSafeArea())
    }
}
