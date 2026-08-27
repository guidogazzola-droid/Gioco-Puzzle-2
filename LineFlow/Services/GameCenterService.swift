import Foundation
import GameKit
import Observation
import UIKit
import PuzzleKit

/// All Game Center traffic in one place.
///
/// Game Center is strictly optional here: a player who is signed out, offline,
/// or blocked by Screen Time restrictions plays the whole game normally and
/// simply sees no leaderboards. Nothing in the game loop waits on this class.
@MainActor
@Observable
final class GameCenterService {

    private(set) var isAuthenticated = false
    /// Set when authentication finished and the player is still not signed in -
    /// declined, restricted, or offline. Used to explain rather than retry
    /// silently forever.
    private(set) var isUnavailable = false
    private(set) var lastError: String?

    /// Where the player currently stands, for the home screen. Empty when
    /// signed out, or when they are not yet ranked on any board.
    private(set) var standings: [Standing] = []

    /// One line of "you are Nth".
    struct Standing: Identifiable, Equatable {
        let leaderboard: LeaderboardID
        let rank: Int
        /// Game Center's own formatting, which already respects the board's
        /// score format - a time renders as a time, not as a number.
        let formattedScore: String

        var id: String { leaderboard.rawValue }
    }

    /// Called once the player signs in, so standings can be re-posted. A send
    /// that failed while offline heals here.
    var onAuthenticated: (() -> Void)?

    private var hasStartedAuthentication = false

    // MARK: - Authentication

    /// Starts Apple's sign-in flow. Safe to call more than once; GameKit keeps
    /// the handler and re-invokes it whenever the player changes.
    func authenticate() {
        guard !hasStartedAuthentication else { return }
        hasStartedAuthentication = true

        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            // Hop rather than assume isolation: GameKit documents this as a
            // main-thread callback, but assuming it would trap if that ever
            // changed, and the hop costs microseconds.
            Task { @MainActor in
                guard let self else { return }
                if let controller {
                    // GameKit wants its sign-in sheet shown.
                    self.present(controller)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.isUnavailable = !self.isAuthenticated
                self.lastError = error?.localizedDescription
                if self.isAuthenticated {
                    self.onAuthenticated?()
                }
            }
        }
    }

    /// Lets the player try again after declining, without a relaunch.
    func retryAuthentication() {
        hasStartedAuthentication = false
        isUnavailable = false
        authenticate()
    }

    // MARK: - Scores

    /// Posts scores, skipping quietly when there is nobody to post as.
    ///
    /// Standings are cumulative and Game Center keeps the best of them, so
    /// re-posting is always safe - which is exactly what makes a submission
    /// lost to a dead connection recover on its own.
    func submit(_ submissions: [LeaderboardSubmission]) {
        guard isAuthenticated, !submissions.isEmpty else { return }
        Task { [submissions] in
            for submission in submissions {
                do {
                    try await GKLeaderboard.submitScore(
                        submission.score,
                        context: submission.context,
                        player: GKLocalPlayer.local,
                        leaderboardIDs: [submission.leaderboard.rawValue]
                    )
                } catch {
                    // Offline, or an identifier that does not exist in App
                    // Store Connect. The second one is silent in production,
                    // so it is worth surfacing here while developing.
                    lastError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Standings

    /// Loads the player's own rank on each board.
    ///
    /// Showing this on the home screen is the point of the whole feature: a
    /// leaderboard nobody navigates to may as well not exist.
    func refreshStandings() async {
        guard isAuthenticated else {
            standings = []
            return
        }
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(
                IDs: LeaderboardID.allCases.map(\.rawValue)
            )
            var found: [Standing] = []
            for board in boards {
                guard let id = LeaderboardID(rawValue: board.baseLeaderboardID) else { continue }
                // The first element is the local player's own entry; the
                // second is the surrounding page, which we do not need.
                let (mine, _) = try await board.loadEntries(
                    for: [GKLocalPlayer.local],
                    timeScope: .allTime
                )
                // Rank 0 means the player has no score on this board yet.
                guard let mine, mine.rank > 0 else { continue }
                found.append(Standing(
                    leaderboard: id,
                    rank: mine.rank,
                    formattedScore: mine.formattedScore
                ))
            }
            standings = found.sorted { $0.leaderboard.displayOrder < $1.leaderboard.displayOrder }
        } catch {
            // Offline is the common case. Keep whatever was shown last rather
            // than blanking the card.
            lastError = error.localizedDescription
        }
    }

    // MARK: - Presentation

    private func present(_ controller: UIViewController) {
        guard let root = Self.topViewController() else { return }
        root.present(controller, animated: true)
    }

    /// The view controller actually on screen - presenting onto one that is
    /// already presenting silently does nothing.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        var controller = scene?.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
