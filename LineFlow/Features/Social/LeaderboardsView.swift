import GameKit
import SwiftUI
import PuzzleKit

/// Hosts Game Center's own leaderboard UI, or explains why it is not there.
///
/// Apple's dashboard is used rather than a hand-rolled table on purpose: it
/// already handles friends, time scopes, avatars and the player's own rank,
/// and players recognise it.
struct LeaderboardsView: View {

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if services.gameCenter.isAuthenticated {
            GameCenterDashboard(state: .leaderboards) { dismiss() }
                .ignoresSafeArea()
        } else {
            signedOut
        }
    }

    private var signedOut: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Ink.gold)

                Text("gamecenter.signedOut.title")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Ink.primary)

                Text("gamecenter.signedOut.body")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Ink.secondary)
                    .padding(.horizontal, 32)

                Button {
                    services.gameCenter.retryAuthentication()
                } label: {
                    Text("gamecenter.signIn")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)

                // What the player is missing, so the prompt is an offer rather
                // than a nag.
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(LeaderboardID.allCases) { board in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: board == .dailyTime ? "calendar" : "chart.bar.fill")
                                .font(.caption)
                                .foregroundStyle(Ink.accent)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(LocalizedStringKey(board.titleKey))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Ink.primary)
                                Text(LocalizedStringKey(board.detailKey))
                                    .font(.caption)
                                    .foregroundStyle(Ink.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 32)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Ink.card.ignoresSafeArea())
            .navigationTitle(Text("home.leaderboards"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text("common.close"))
                }
            }
        }
    }
}

/// Thin bridge to `GKGameCenterViewController`, which has no SwiftUI form.
struct GameCenterDashboard: UIViewControllerRepresentable {

    let state: GKGameCenterViewControllerState
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller = GKGameCenterViewController(state: state)
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            onFinish()
        }
    }
}
