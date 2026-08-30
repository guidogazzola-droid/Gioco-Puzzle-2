import SwiftUI
import PuzzleKit

/// The two rankings that matter while starting a campaign level: the player's
/// total stars and their progress on the track they are currently playing.
struct LevelStandingsSummary: Equatable {
    struct Item: Identifiable, Equatable {
        let leaderboard: LeaderboardID
        let rank: Int
        let formattedScore: String
        /// Positive means places gained; negative means places lost.
        let rankChange: Int

        var id: String { leaderboard.rawValue }
    }

    let items: [Item]

    static func make(
        standings: [GameCenterService.Standing],
        track: LevelTrack,
        previousRanks: [LeaderboardID: Int]
    ) -> Self {
        let trackBoard: LeaderboardID = track == .pro ? .proTrack : .freeTrack
        let wanted: [LeaderboardID] = [.totalStars, trackBoard]
        let byBoard = Dictionary(uniqueKeysWithValues: standings.map { ($0.leaderboard, $0) })

        return Self(items: wanted.compactMap { leaderboard in
            guard let standing = byBoard[leaderboard] else { return nil }
            let previous = previousRanks[leaderboard] ?? standing.rank
            return Item(
                leaderboard: leaderboard,
                rank: standing.rank,
                formattedScore: standing.formattedScore,
                rankChange: previous - standing.rank
            )
        })
    }
}

/// A short-lived, tappable overlay. It keeps the cube usable and opens the
/// complete Game Center dashboard only when the player asks for more detail.
struct LevelStandingsBanner: View {
    let summary: LevelStandingsSummary
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label("game.standing.title", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Ink.primary)
                    Spacer()
                    Text("game.standing.open")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Ink.accent)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Ink.accent)
                }

                HStack(spacing: 10) {
                    ForEach(summary.items) { item in
                        standing(item)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Ink.cardRaised.opacity(0.97))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Ink.gold.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("game.standing.accessibilityHint"))
    }

    private func standing(_ item: LevelStandingsSummary.Item) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(item.leaderboard.shortTitleKey))
                    .font(.caption2)
                    .foregroundStyle(Ink.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("#\(item.rank)")
                        .font(.title3.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Ink.gold)
                    if item.rankChange != 0 {
                        rankChange(item.rankChange)
                    }
                }
                Text(item.formattedScore)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Ink.card)
        )
    }

    private func rankChange(_ change: Int) -> some View {
        Label("\(abs(change))", systemImage: change > 0 ? "arrow.up" : "arrow.down")
            .font(.caption2.weight(.bold).monospacedDigit())
            .foregroundStyle(change > 0 ? Ink.accent : Ink.secondary)
            .accessibilityLabel(Text(String(
                format: NSLocalizedString(
                    change > 0 ? "game.standing.gained" : "game.standing.lost",
                    comment: "Leaderboard rank change"
                ),
                abs(change)
            )))
    }
}
