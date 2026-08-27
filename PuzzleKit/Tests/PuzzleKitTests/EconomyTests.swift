import Foundation
import Testing
@testable import PuzzleKit

struct ScoreRulesTests {

    @Test("three stars need a perfect, hint-free solve")
    func perfectSolveEarnsThreeStars() {
        #expect(ScoreRules.stars(moves: 6, par: 6, hintsUsed: 0) == 3)
        #expect(ScoreRules.stars(moves: 5, par: 6, hintsUsed: 0) == 3)
        #expect(ScoreRules.stars(moves: 7, par: 6, hintsUsed: 0) == 2)
    }

    @Test("the two-star budget scales with the board")
    func twoStarBudgetScales() {
        #expect(ScoreRules.stars(moves: 9, par: 6, hintsUsed: 0) == 2)
        #expect(ScoreRules.stars(moves: 10, par: 6, hintsUsed: 0) == 1)
        // Small boards still get a usable margin rather than par/2 == 1.
        #expect(ScoreRules.twoStarBudget(par: 3) == 2)
    }

    @Test("a hint caps the award at two stars")
    func hintsCapTheAward() {
        #expect(ScoreRules.stars(moves: 6, par: 6, hintsUsed: 1) == 2)
        #expect(ScoreRules.stars(moves: 3, par: 6, hintsUsed: 2) == 2)
        #expect(ScoreRules.stars(moves: 40, par: 6, hintsUsed: 1) == 1)
    }

    @Test("replays pay less than a first clear")
    func replaysPayLess() {
        let parameters = DifficultyCurve.parameters(level: 12, track: .free)
        let first = ScoreRules.gems(stars: 3, parameters: parameters, isFirstClear: true)
        let replay = ScoreRules.gems(stars: 3, parameters: parameters, isFirstClear: false)
        #expect(replay < first)
        #expect(replay >= 1)
    }

    @Test("boss levels and Pro multipliers pay more")
    func bonusesApply() {
        let normal = DifficultyCurve.parameters(level: 12, track: .free)
        let boss = DifficultyCurve.parameters(level: 20, track: .free)
        #expect(boss.isBoss)
        #expect(ScoreRules.gems(stars: 3, parameters: boss, isFirstClear: true)
                > ScoreRules.gems(stars: 3, parameters: normal, isFirstClear: true))

        let plain = ScoreRules.gems(stars: 3, parameters: normal, isFirstClear: true, multiplier: 1)
        let pro = ScoreRules.gems(stars: 3, parameters: normal, isFirstClear: true, multiplier: 2)
        #expect(pro == plain * 2)
    }

    @Test("an outcome carries consistent stars and gems")
    func outcomeIsConsistent() {
        let parameters = DifficultyCurve.parameters(level: 12, track: .free)
        let outcome = ScoreRules.outcome(
            level: 12, track: .free, parameters: parameters,
            moves: 4, par: 4, seconds: 31, hintsUsed: 0,
            isFirstClear: true, gemMultiplier: 1
        )
        #expect(outcome.stars == 3)
        #expect(outcome.isPerfect)
        #expect(outcome.gems > 0)
        #expect(outcome.level == 12)
    }
}

struct EntitlementsTests {

    private let orchid = CosmeticCatalog.cosmetic(id: "orchid")!
    private let glacier = CosmeticCatalog.cosmetic(id: "glacier")!
    private let tide = CosmeticCatalog.cosmetic(id: "tide")!
    private let ember = CosmeticCatalog.cosmetic(id: "ember")!
    private let aurora = CosmeticCatalog.cosmetic(id: "aurora")!

    @Test("a brand new player sees ads and owns only the free items")
    func freshPlayerDefaults() {
        let entitlements = Entitlements()
        #expect(entitlements.showsAds)
        #expect(!entitlements.isPro)
        #expect(!entitlements.unlocksProTrack)
        #expect(entitlements.gemMultiplier == 1)
        #expect(entitlements.canUse(aurora))
        #expect(!entitlements.canUse(glacier))
        #expect(!entitlements.canUse(orchid))
    }

    @Test("buying remove-ads stops ads without unlocking Pro content")
    func removeAdsIsNarrow() {
        let entitlements = Entitlements(hasRemoveAdsPurchase: true)
        #expect(!entitlements.showsAds)
        #expect(!entitlements.isPro)
        #expect(!entitlements.unlocksProTrack)
        #expect(!entitlements.canUse(glacier))
        #expect(entitlements.gemMultiplier == 1)
    }

    @Test("an active subscription unlocks everything")
    func proUnlocksEverything() {
        let entitlements = Entitlements(
            pro: .active(expiresAt: Date().addingTimeInterval(86_400), isTrial: false, willAutoRenew: true)
        )
        #expect(entitlements.isPro)
        #expect(!entitlements.showsAds)
        #expect(entitlements.unlocksProTrack)
        #expect(entitlements.hasUnlimitedHints)
        #expect(entitlements.gemMultiplier == 2)
        for cosmetic in CosmeticCatalog.all {
            #expect(entitlements.canUse(cosmetic), "Pro should unlock \(cosmetic.id)")
        }
    }

    @Test("a free trial is treated as a full subscription")
    func trialIsEntitled() {
        let entitlements = Entitlements(
            pro: .active(expiresAt: Date().addingTimeInterval(600), isTrial: true, willAutoRenew: true)
        )
        #expect(entitlements.isPro)
        #expect(entitlements.pro.isInTrial)
        #expect(!entitlements.showsAds)
    }

    @Test("a grace period keeps serving, a billing retry does not")
    func billingStatesAreDistinguished() {
        let grace = Entitlements(pro: .gracePeriod(expiresAt: Date().addingTimeInterval(3_600)))
        #expect(grace.isPro)
        #expect(!grace.showsAds)
        #expect(grace.pro.needsAttention)

        let retry = Entitlements(pro: .billingRetry)
        #expect(!retry.isPro)
        #expect(retry.showsAds)
        #expect(retry.pro.needsAttention)
    }

    @Test("a revoked purchase is treated as never bought")
    func revocationRemovesAccess() {
        let entitlements = Entitlements(pro: .revoked)
        #expect(!entitlements.isPro)
        #expect(entitlements.showsAds)
        #expect(!entitlements.canUse(glacier))
    }

    @Test("gem and star unlocks are owned outright")
    func earnedItemsAreOwned() {
        let entitlements = Entitlements(ownedCosmetics: ["ember"], starTotal: 20)
        #expect(entitlements.canUse(ember))
        #expect(entitlements.isOwnedOutright(ember))
        #expect(entitlements.canUse(tide))          // 15 stars required
        #expect(!entitlements.canUse(CosmeticCatalog.cosmetic(id: "mesh")!))  // 40 stars
    }

    @Test("what the player paid for survives a lapsed subscription")
    func purchasesOutliveTheSubscription() {
        let subscribed = Entitlements(
            pro: .active(expiresAt: nil, isTrial: false, willAutoRenew: true),
            purchasedProducts: [.stylePackOrchid],
            ownedCosmetics: ["ember"],
            starTotal: 30
        )
        #expect(subscribed.canUse(glacier))

        var lapsed = subscribed
        lapsed.pro = .expired(at: Date())
        #expect(!lapsed.isPro)
        #expect(lapsed.canUse(orchid), "a paid style pack must not be revoked")
        #expect(lapsed.canUse(ember), "gems already spent must not be revoked")
        #expect(lapsed.canUse(tide), "earned star unlocks must not be revoked")
        #expect(!lapsed.canUse(glacier), "Pro-only items go back behind the paywall")
    }

    @Test("a lapsed subscription reverts only the items it granted")
    func lapsedSubscriptionDowngradesGracefully() {
        var equipped = EquippedCosmetics()
        equipped.palette = "glacier"          // Pro only
        equipped.trail = "glow"               // bought with gems
        equipped.background = "starfield"     // bought with money
        equipped.nodeShape = "bloom"          // Pro only

        let lapsed = Entitlements(
            pro: .expired(at: Date()),
            purchasedProducts: [.stylePackNeon],
            ownedCosmetics: ["glow"]
        )
        let sanitized = lapsed.sanitized(equipped)
        #expect(sanitized.palette == CosmeticCatalog.defaultPalette)
        #expect(sanitized.nodeShape == CosmeticCatalog.defaultNodeShape)
        #expect(sanitized.trail == "glow")
        #expect(sanitized.background == "starfield")
    }

    @Test("sanitising leaves a fully entitled loadout untouched")
    func sanitisingIsIdempotentForPro() {
        var equipped = EquippedCosmetics()
        equipped.palette = "nebula"
        equipped.trail = "plasma"
        let pro = Entitlements(pro: .active(expiresAt: nil, isTrial: false, willAutoRenew: true))
        #expect(pro.sanitized(equipped) == equipped)
    }

    @Test("an unknown cosmetic id is never usable")
    func unknownIdsAreRejected() {
        let pro = Entitlements(pro: .active(expiresAt: nil, isTrial: false, willAutoRenew: true))
        #expect(!pro.canUse(cosmeticID: "does-not-exist"))
        // ...and sanitising replaces it rather than leaving the board unpainted.
        var equipped = EquippedCosmetics()
        equipped.palette = "does-not-exist"
        #expect(pro.sanitized(equipped).palette == CosmeticCatalog.defaultPalette)
    }

    @Test("lock reasons tell the player exactly what is missing")
    func lockReasonsAreSpecific() {
        let entitlements = Entitlements()
        #expect(entitlements.lockReason(for: aurora) == nil)
        #expect(entitlements.lockReason(for: ember) == .needsGems(250))
        #expect(entitlements.lockReason(for: tide) == .needsStars(15))
        #expect(entitlements.lockReason(for: orchid) == .needsPurchase(.stylePackOrchid))
        #expect(entitlements.lockReason(for: glacier) == .needsPro)
    }

    @Test("entitlements survive a round trip through the save file")
    func entitlementsAreCodable() throws {
        let original = Entitlements(
            hasRemoveAdsPurchase: true,
            pro: .gracePeriod(expiresAt: Date(timeIntervalSince1970: 1_800_000_000)),
            purchasedProducts: [.stylePackNeon, .removeAds],
            ownedCosmetics: ["ember", "glow"],
            starTotal: 77
        )
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(Entitlements.self, from: data) == original)
    }
}

struct AdPolicyTests {

    private let free = Entitlements()
    private let policy = AdPolicy.standard

    @Test("paying players never see an interstitial")
    func payingPlayersAreExempt() {
        let state = AdState(levelsSinceInterstitial: 99)
        for entitlements in [
            Entitlements(hasRemoveAdsPurchase: true),
            Entitlements(pro: .active(expiresAt: nil, isTrial: false, willAutoRenew: true)),
            Entitlements(pro: .gracePeriod(expiresAt: nil))
        ] {
            #expect(!policy.shouldShowInterstitial(
                entitlements: entitlements, state: state, levelsCompleted: 200
            ))
        }
    }

    @Test("new players get an ad-free run at the game first")
    func newPlayerGraceWindow() {
        let state = AdState(levelsSinceInterstitial: 99)
        for completed in 0...policy.newPlayerGraceLevels {
            #expect(!policy.shouldShowInterstitial(
                entitlements: free, state: state, levelsCompleted: completed
            ))
        }
        #expect(policy.shouldShowInterstitial(
            entitlements: free, state: state, levelsCompleted: policy.newPlayerGraceLevels + 1
        ))
    }

    @Test("interstitials are spaced by completed levels")
    func levelSpacingIsRespected() {
        for since in 0..<policy.levelsBetweenInterstitials {
            #expect(!policy.shouldShowInterstitial(
                entitlements: free,
                state: AdState(levelsSinceInterstitial: since),
                levelsCompleted: 50
            ))
        }
        #expect(policy.shouldShowInterstitial(
            entitlements: free,
            state: AdState(levelsSinceInterstitial: policy.levelsBetweenInterstitials),
            levelsCompleted: 50
        ))
    }

    @Test("a fast player is not carpet-bombed")
    func timeSpacingIsRespected() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let justShown = AdState(levelsSinceInterstitial: 10, lastInterstitialAt: now.addingTimeInterval(-10))
        #expect(!policy.shouldShowInterstitial(
            entitlements: free, state: justShown, levelsCompleted: 50, now: now
        ))

        let longAgo = AdState(
            levelsSinceInterstitial: 10,
            lastInterstitialAt: now.addingTimeInterval(-policy.minimumSecondsBetween - 1)
        )
        #expect(policy.shouldShowInterstitial(
            entitlements: free, state: longAgo, levelsCompleted: 50, now: now
        ))
    }

    @Test("a player who just failed is never interrupted")
    func failuresAreNotMonetised() {
        let state = AdState(levelsSinceInterstitial: 99)
        #expect(!policy.shouldShowInterstitial(
            entitlements: free, state: state, levelsCompleted: 50, afterSuccess: false
        ))
        #expect(policy.shouldShowInterstitial(
            entitlements: free, state: state, levelsCompleted: 50, afterSuccess: true
        ))
    }

    @Test("showing an ad resets the pacing counters")
    func consumingResetsState() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let consumed = policy.consumed(AdState(levelsSinceInterstitial: 7), now: now)
        #expect(consumed.levelsSinceInterstitial == 0)
        #expect(consumed.lastInterstitialAt == now)
        #expect(!policy.shouldShowInterstitial(
            entitlements: free, state: consumed, levelsCompleted: 50, now: now
        ))
    }

    @Test("rewarded placements grant exactly one kind of reward")
    func rewardedPlacementsAreDistinct() {
        #expect(RewardedPlacement.hint.hintReward > 0)
        #expect(RewardedPlacement.hint.gemReward == 0)
        #expect(RewardedPlacement.gems.gemReward > 0)
        #expect(RewardedPlacement.gems.hintReward == 0)
        #expect(RewardedPlacement.proTrial.gemReward == 0)
        #expect(RewardedPlacement.proTrial.hintReward == 0)
    }
}
