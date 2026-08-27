import Foundation

/// When an interstitial is allowed to interrupt the player.
///
/// A hybrid-casual title lives and dies on this balance: too few ads and the
/// free tier earns nothing, too many and retention collapses before the player
/// ever sees the paywall. The rules are data here, and unit-tested, so they can
/// be tuned from analytics without touching the game loop.
public struct AdPolicy: Sendable, Hashable, Codable {

    /// Completed levels between two interstitials.
    ///
    /// Four rather than three since the advertisements became our own: the
    /// number used to be a compromise between revenue and retention, and with
    /// no third-party network there is no revenue side to the trade any more.
    /// It is chosen purely for how the game feels.
    public var levelsBetweenInterstitials: Int
    /// No interstitial at all until the player has finished this many levels.
    /// The first session has to sell the game, not the ad inventory.
    public var newPlayerGraceLevels: Int
    /// Floor on the wall-clock gap between interstitials, so a fast player on
    /// easy levels is not carpet-bombed.
    public var minimumSecondsBetween: TimeInterval
    /// Never interrupt a player who just failed or restarted - only successes.
    public var showsOnlyAfterSuccess: Bool

    public init(
        levelsBetweenInterstitials: Int = 4,
        newPlayerGraceLevels: Int = 5,
        minimumSecondsBetween: TimeInterval = 90,
        showsOnlyAfterSuccess: Bool = true
    ) {
        self.levelsBetweenInterstitials = levelsBetweenInterstitials
        self.newPlayerGraceLevels = newPlayerGraceLevels
        self.minimumSecondsBetween = minimumSecondsBetween
        self.showsOnlyAfterSuccess = showsOnlyAfterSuccess
    }

    public static let standard = AdPolicy()

    /// Whether an interstitial may be shown right now.
    /// - Parameters:
    ///   - entitlements: paying players never see one.
    ///   - state: persisted pacing counters.
    ///   - levelsCompleted: lifetime completed levels, for the grace window.
    ///   - afterSuccess: whether the player just cleared a board. Interrupting
    ///     someone who just failed is the fastest way to lose them.
    public func shouldShowInterstitial(
        entitlements: Entitlements,
        state: AdState,
        levelsCompleted: Int,
        afterSuccess: Bool = true,
        now: Date = Date()
    ) -> Bool {
        guard entitlements.showsAds else { return false }
        if showsOnlyAfterSuccess && !afterSuccess { return false }
        guard levelsCompleted > newPlayerGraceLevels else { return false }
        guard state.levelsSinceInterstitial >= levelsBetweenInterstitials else { return false }
        if let last = state.lastInterstitialAt,
           now.timeIntervalSince(last) < minimumSecondsBetween {
            return false
        }
        return true
    }

    /// The pacing state after an interstitial has actually been shown.
    public func consumed(_ state: AdState, now: Date = Date()) -> AdState {
        AdState(levelsSinceInterstitial: 0, lastInterstitialAt: now)
    }
}

/// What a rewarded video is being watched for.
public enum RewardedPlacement: String, Sendable, Codable, CaseIterable {
    /// One hint, offered on the board when the player is stuck.
    case hint
    /// A pile of gems, offered from the shop.
    case gems
    /// A single-run peek at the Pro track, offered from the paywall. This is
    /// the strongest free-to-paid bridge the game has: let people feel the
    /// thing before asking them to subscribe.
    case proTrial

    public var gemReward: Int {
        switch self {
        case .hint: 0
        case .gems: ProductCatalog.gemsPerRewardedAd
        case .proTrial: 0
        }
    }

    public var hintReward: Int {
        switch self {
        case .hint: ProductCatalog.hintsPerRewardedAd
        case .gems, .proTrial: 0
        }
    }
}
