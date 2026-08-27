import Foundation
import Observation
import PuzzleKit

/// The object graph the whole app hangs off, and the only place where the
/// save file, the App Store and the ad network meet.
///
/// Views read state from here and call intents on it; none of them talk to
/// StoreKit or the ad service directly.
@MainActor
@Observable
final class AppServices {

    let profileStore: ProfileStore
    let store: StoreManager
    let ads: HouseAdService
    let haptics: HapticsService
    let gameCenter: GameCenterService
    let adPolicy: AdPolicy

    /// Set when a purchase or restore needs to say something to the player.
    var banner: Banner?

    struct Banner: Identifiable, Equatable {
        enum Style { case success, info, failure }
        let id = UUID()
        let messageKey: String
        let style: Style
    }

    /// Every service is injectable so tests can hand in a throwaway save
    /// file. The defaults are `nil` rather than freshly built objects because
    /// a default argument expression is evaluated outside the initialiser's
    /// isolation, and these services are all main-actor bound.
    init(
        profileStore: ProfileStore? = nil,
        store: StoreManager? = nil,
        ads: HouseAdService? = nil,
        haptics: HapticsService? = nil,
        gameCenter: GameCenterService? = nil,
        adPolicy: AdPolicy = .standard
    ) {
        self.profileStore = profileStore ?? ProfileStore()
        self.store = store ?? StoreManager()
        self.ads = ads ?? HouseAdService()
        self.haptics = haptics ?? HapticsService()
        self.gameCenter = gameCenter ?? GameCenterService()
        self.adPolicy = adPolicy
    }

    /// Wires the services together and starts listening for transactions.
    func bootstrap() {
        haptics.isEnabled = profile.settings.hapticsEnabled
        ads.configure(allowsPersonalisedAds: false)

        store.onConsumablePurchased = { [weak self] product in
            self?.creditConsumable(product)
        }
        store.onUnlockPurchased = { [weak self] product in
            self?.grantUnlock(product)
        }
        store.start()

        // Re-post standings once the player signs in: a score lost to a dead
        // connection is recovered here rather than being gone for good.
        gameCenter.onAuthenticated = { [weak self] in
            guard let self else { return }
            gameCenter.submit(LeaderboardRules.standings(for: profile))
            Task { await self.gameCenter.refreshStandings() }
        }
        gameCenter.authenticate()
    }

    // MARK: - Derived state

    var profile: PlayerProfile { profileStore.profile }

    /// The merge point: App Store facts plus save-file facts.
    var entitlements: Entitlements {
        Entitlements(
            hasRemoveAdsPurchase: store.hasRemoveAdsPurchase,
            pro: store.proState,
            purchasedProducts: store.purchasedProducts,
            ownedCosmetics: profile.ownedCosmetics,
            starTotal: profile.totalStars
        )
    }

    var theme: GameTheme {
        GameTheme.resolve(entitlements.sanitized(profile.equipped))
    }

    var showsAds: Bool { entitlements.showsAds }

    var canPlayProTrack: Bool { entitlements.unlocksProTrack }

    var todayKey: String { DayKey.key(for: Date()) }

    var hasClearedTodaysDaily: Bool { profile.hasClearedDaily(on: todayKey) }

    // MARK: - Playing

    /// Books a finished campaign level and returns what the player earned.
    func finish(
        engine: PuzzleEngine,
        seconds: Int,
        track: LevelTrack
    ) -> LevelOutcome {
        let level = engine.blueprint.level
        let parameters = DifficultyCurve.parameters(level: level, track: track)
        let outcome = ScoreRules.outcome(
            level: level,
            track: track,
            parameters: parameters,
            moves: engine.moves,
            par: engine.parMoves,
            seconds: seconds,
            hintsUsed: engine.hintsUsed,
            isFirstClear: !profile.progress(for: track).isCleared(level),
            gemMultiplier: entitlements.gemMultiplier
        )
        profileStore.update { $0.apply(outcome, on: DayKey.key(for: Date())) }
        haptics.play(.win)
        gameCenter.submit(LeaderboardRules.afterCampaignLevel(profile: profile))
        return outcome
    }

    /// Books the daily board, or returns `nil` if it was already claimed today.
    func finishDaily(
        engine: PuzzleEngine,
        seconds: Int
    ) -> (outcome: LevelOutcome, bonus: Int)? {
        let day = todayKey
        guard !profile.hasClearedDaily(on: day) else { return nil }

        let level = engine.blueprint.level
        let parameters = DifficultyCurve.parameters(level: level, track: .free)
        let outcome = ScoreRules.outcome(
            level: level, track: .free, parameters: parameters,
            moves: engine.moves, par: engine.parMoves, seconds: seconds,
            hintsUsed: engine.hintsUsed, isFirstClear: true,
            gemMultiplier: entitlements.gemMultiplier
        )
        let bonus = DailyChallenge.bonusGems(stars: outcome.stars, streak: profile.stats.currentStreak)
        profileStore.update { $0.applyDaily(outcome, on: day, bonusGems: bonus) }
        haptics.play(.win)
        gameCenter.submit(LeaderboardRules.afterDaily(outcome: outcome, profile: profile))
        return (outcome, bonus)
    }

    // MARK: - Hints

    var hasFreeHint: Bool { entitlements.hasUnlimitedHints || profile.hints > 0 }

    /// Spends a hint if one is available. Pro subscribers are never charged.
    func consumeHint() -> Bool {
        if entitlements.hasUnlimitedHints { return true }
        var spent = false
        profileStore.update { spent = $0.spendHint() }
        return spent
    }

    func buyHintWithGems() -> Bool {
        var bought = false
        profileStore.update { profile in
            guard profile.spendGems(ProductCatalog.hintGemCost) else { return }
            profile.hints += 1
            bought = true
        }
        if bought { haptics.play(.reward) }
        return bought
    }

    // MARK: - Ads

    /// House advertisements this player should not be shown. Selling the
    /// subscription to somebody who already pays for it reads as an app that
    /// is not keeping track.
    private var suppressedAdIDs: Set<String> {
        entitlements.isPro ? [HouseAdCatalogue.pro.id] : []
    }

    /// Shows an interstitial if the pacing rules allow one. Returns whether it
    /// was shown, so the caller can wait before pushing the next screen.
    @discardableResult
    func showInterstitialIfDue(afterSuccess: Bool = true) async -> Bool {
        guard adPolicy.shouldShowInterstitial(
            entitlements: entitlements,
            state: profile.ads,
            levelsCompleted: profile.stats.levelsCompleted,
            afterSuccess: afterSuccess
        ) else { return false }

        ads.suppressedAdIDs = suppressedAdIDs
        await ads.showInterstitial()
        profileStore.update { $0.ads = adPolicy.consumed($0.ads) }
        return true
    }

    /// Plays a rewarded video and grants the reward only if it completed.
    @discardableResult
    func watchRewarded(_ placement: RewardedPlacement) async -> Bool {
        ads.suppressedAdIDs = suppressedAdIDs
        guard await ads.showRewarded(placement) else { return false }
        profileStore.update { profile in
            profile.hints += placement.hintReward
            profile.gems += placement.gemReward
        }
        haptics.play(.reward)
        return true
    }

    // MARK: - Store

    func purchase(_ product: StoreProductID) async {
        switch await store.purchase(product) {
        case .purchased:
            banner = Banner(messageKey: "store.banner.purchased", style: .success)
            haptics.play(.reward)
        case .pending:
            banner = Banner(messageKey: "store.banner.pending", style: .info)
        case .cancelled:
            break
        case .failed:
            banner = Banner(messageKey: "store.banner.failed", style: .failure)
        }
    }

    func restorePurchases() async {
        let restored = await store.restorePurchases()
        banner = Banner(
            messageKey: restored ? "store.banner.restored" : "store.banner.restoreFailed",
            style: restored ? .success : .failure
        )
    }

    private func creditConsumable(_ product: StoreProductID) {
        guard product.gemGrant > 0 else { return }
        profileStore.update { $0.gems += product.gemGrant }
    }

    private func grantUnlock(_ product: StoreProductID) {
        let cosmetics = product.grantedCosmetics
        guard !cosmetics.isEmpty else { return }
        profileStore.update { profile in
            for id in cosmetics { profile.ownedCosmetics.insert(id) }
        }
    }

    // MARK: - Cosmetics

    /// Buys a gem-priced cosmetic. Returns `false` if the player cannot afford
    /// it or it is not sold for gems.
    @discardableResult
    func buyWithGems(_ cosmetic: Cosmetic) -> Bool {
        guard case .gems(let price) = cosmetic.unlock else { return false }
        var bought = false
        profileStore.update { profile in
            guard profile.spendGems(price) else { return }
            profile.ownedCosmetics.insert(cosmetic.id)
            bought = true
        }
        if bought {
            haptics.play(.reward)
            equip(cosmetic)
        }
        return bought
    }

    /// Equips a cosmetic the player is entitled to. Silently ignores anything
    /// still locked, so a stale view cannot put the board in a bad state.
    func equip(_ cosmetic: Cosmetic) {
        guard entitlements.canUse(cosmetic) else { return }
        profileStore.update { $0.equipped.set(cosmetic.id, for: cosmetic.category) }
        haptics.play(.snap)
    }

    func isEquipped(_ cosmetic: Cosmetic) -> Bool {
        profile.equipped.id(for: cosmetic.category) == cosmetic.id
    }

    // MARK: - Settings

    /// Reloads where the player stands. Cheap and safe to call on appear.
    func refreshStandings() async {
        await gameCenter.refreshStandings()
    }

    func updateSettings(_ mutate: (inout GameSettings) -> Void) {
        profileStore.update { mutate(&$0.settings) }
        haptics.isEnabled = profile.settings.hapticsEnabled
    }

    func completeOnboarding() {
        profileStore.update { $0.onboardingComplete = true }
    }

    /// Wipes progress while keeping the things the player paid for: purchased
    /// cosmetics, their settings, and anything StoreKit knows about. Deleting
    /// a purchase because someone tapped "reset" would be indefensible.
    func resetProgress() {
        let settings = profile.settings
        let owned = profile.ownedCosmetics
        profileStore.update { profile in
            profile = PlayerProfile(
                ownedCosmetics: owned,
                equipped: EquippedCosmetics(),
                settings: settings,
                onboardingComplete: true
            )
        }
        reconcileEquippedCosmetics()
    }

    /// Drops any cosmetic the player is no longer entitled to. Called whenever
    /// entitlements change, so a lapsed subscription degrades quietly rather
    /// than leaving a locked skin on the board.
    func reconcileEquippedCosmetics() {
        let sanitized = entitlements.sanitized(profile.equipped)
        guard sanitized != profile.equipped else { return }
        profileStore.update { $0.equipped = sanitized }
    }
}
