import Foundation
import Observation
import PuzzleKit

/// What an ad network has to provide for the game to work.
///
/// Every ad call the game makes goes through these four methods, so swapping
/// the vendor means writing one conformance and changing the type of
/// `AppServices.ads`. `HouseAdService` is what ships in the repository: it
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

/// What the ad UI is currently showing.
struct AdPresentation: Identifiable, Equatable {
    enum Kind: Equatable {
        case interstitial
        case rewarded(RewardedPlacement)
    }

    let id = UUID()
    let kind: Kind
    let duration: TimeInterval
    /// The creative to render. Carried on the presentation rather than looked
    /// up by the view, so the rotation is decided once, by the service.
    let ad: HouseAd

    var isRewarded: Bool {
        if case .rewarded = kind { return true }
        return false
    }
}

/// Serves the game's own advertisements.
///
/// It behaves the way a network's unit does where it matters: a fixed
/// non-skippable window, a rewarded unit that only pays out if watched to the
/// end, and an async call that does not return until it is dismissed. Which
/// means swapping in a real network later changes what fills the window, not
/// how the game asks for it.
@MainActor
@Observable
final class HouseAdService: AdService {

    /// Observed by the root view, which presents the unit over the game.
    private(set) var presentation: AdPresentation?
    private(set) var allowsPersonalisedAds = false

    /// Creatives this player must not be shown. `AppServices` sets it before
    /// each presentation: advertising the subscription to a subscriber is the
    /// kind of thing that makes an app feel like it is not paying attention.
    var suppressedAdIDs: Set<String> = []

    private var lastShownID: String?

    var isInterstitialReady: Bool { presentation == nil }
    var isRewardedReady: Bool { presentation == nil }

    private var continuation: CheckedContinuation<Bool, Never>?

    func configure(allowsPersonalisedAds: Bool) {
        self.allowsPersonalisedAds = allowsPersonalisedAds
    }

    func preload() {}

    func showInterstitial() async {
        _ = await present(AdPresentation(kind: .interstitial, duration: 5, ad: nextAd()))
    }

    func showRewarded(_ placement: RewardedPlacement) async -> Bool {
        await present(AdPresentation(kind: .rewarded(placement), duration: 8, ad: nextAd()))
    }

    private func nextAd() -> HouseAd {
        let ad = HouseAdCatalogue.next(after: lastShownID, excluding: suppressedAdIDs)
        lastShownID = ad.id
        return ad
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
