import Foundation
import Observation
import PuzzleKit

/// What an ad network has to provide for the game to work.
///
/// Every ad call the game makes goes through these four methods, so swapping
/// the vendor means writing one conformance and changing the type of
/// `AppServices.ads`. `SimulatedAdService` is what ships in the repository: it
/// renders an in-app placeholder, which keeps the project buildable with no
/// third-party dependency and lets the pacing rules be exercised in the
/// simulator. `AppServices` holds it by its concrete type for one reason -
/// the root view needs `presentation` to know when to draw the placeholder -
/// and that overlay is the other half of what a real network replaces.
/// `docs/MONETIZATION.md` walks through wiring AdMob behind this protocol.
@MainActor
protocol AdService: AnyObject {
    /// Whether an interstitial can be shown right now.
    var isInterstitialReady: Bool { get }
    var isRewardedReady: Bool { get }

    /// Called once at launch, and again after consent changes.
    func configure(allowsPersonalisedAds: Bool)
    func preload()

    /// Shows a full-screen ad and returns when it has been dismissed.
    func showInterstitial() async

    /// Shows a rewarded video. Returns `true` only if it played to the end -
    /// the caller must not grant the reward otherwise.
    func showRewarded(_ placement: RewardedPlacement) async -> Bool
}

/// What the placeholder ad UI is currently showing.
struct AdPresentation: Identifiable, Equatable {
    enum Kind: Equatable {
        case interstitial
        case rewarded(RewardedPlacement)
    }

    let id = UUID()
    let kind: Kind
    let duration: TimeInterval

    var isRewarded: Bool {
        if case .rewarded = kind { return true }
        return false
    }
}

/// In-app stand-in for a real ad network.
///
/// It behaves like one where it matters: a fixed non-skippable window, a
/// rewarded video that only pays out if watched to the end, and an async call
/// that does not return until the unit is dismissed.
@MainActor
@Observable
final class SimulatedAdService: AdService {

    /// Observed by the root view, which presents the placeholder over the game.
    private(set) var presentation: AdPresentation?
    private(set) var allowsPersonalisedAds = false

    var isInterstitialReady: Bool { presentation == nil }
    var isRewardedReady: Bool { presentation == nil }

    private var continuation: CheckedContinuation<Bool, Never>?

    func configure(allowsPersonalisedAds: Bool) {
        self.allowsPersonalisedAds = allowsPersonalisedAds
    }

    func preload() {}

    func showInterstitial() async {
        _ = await present(AdPresentation(kind: .interstitial, duration: 5))
    }

    func showRewarded(_ placement: RewardedPlacement) async -> Bool {
        await present(AdPresentation(kind: .rewarded(placement), duration: 8))
    }

    /// Called by the placeholder UI when the player dismisses it.
    /// - Parameter completed: whether the unit ran to the end.
    func finish(completed: Bool) {
        presentation = nil
        continuation?.resume(returning: completed)
        continuation = nil
    }

    private func present(_ ad: AdPresentation) async -> Bool {
        guard presentation == nil else { return false }
        presentation = ad
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}
