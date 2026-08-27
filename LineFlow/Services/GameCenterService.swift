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
