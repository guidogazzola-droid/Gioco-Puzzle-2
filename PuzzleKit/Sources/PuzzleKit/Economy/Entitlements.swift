import Foundation

/// Where a Prism Flow Pro subscription currently stands.
///
/// Grace period is deliberately entitled and billing retry is not: Apple keeps
/// serving content during a grace period while it retries the charge, and
/// cutting the player off mid-grace is both wrong and a refund magnet.
public enum ProSubscriptionState: Sendable, Hashable, Codable {
    case notSubscribed
    case active(expiresAt: Date?, isTrial: Bool, willAutoRenew: Bool)
    /// Payment failed but Apple is still serving the entitlement.
    case gracePeriod(expiresAt: Date?)
    /// Payment failed, entitlement suspended, Apple is still retrying.
    case billingRetry
    case expired(at: Date?)
    /// Refunded or revoked by Apple - treat exactly like never having bought.
    case revoked

    public var grantsAccess: Bool {
        switch self {
        case .active, .gracePeriod: true
        case .notSubscribed, .billingRetry, .expired, .revoked: false
        }
    }

    public var isInTrial: Bool {
        if case .active(_, let isTrial, _) = self { return isTrial }
        return false
    }

    /// True when the player should be nudged to fix their billing details.
    public var needsAttention: Bool {
        switch self {
        case .gracePeriod, .billingRetry: true
        default: false
        }
    }

    public var expiresAt: Date? {
        switch self {
        case .active(let date, _, _): date
        case .gracePeriod(let date): date
        case .expired(let date): date
        case .notSubscribed, .billingRetry, .revoked: nil
        }
    }
}

/// Why a cosmetic cannot be equipped yet.
public enum LockReason: Hashable, Sendable {
    case needsGems(Int)
    case needsStars(Int)
    case needsPurchase(StoreProductID)
    case needsPro
}

/// The single source of truth for "what is this player allowed to do".
///
/// Everything that gates content reads from here, so the rules live in one
/// unit-tested place instead of being re-derived in each view.
public struct Entitlements: Sendable, Hashable, Codable {

    /// The one-off "remove ads" purchase.
    public var hasRemoveAdsPurchase: Bool
    public var pro: ProSubscriptionState
    /// Non-consumables the player has bought.
    public var purchasedProducts: Set<StoreProductID>
    /// Cosmetics owned outright: bought with gems, unlocked by stars, or
    /// granted by a one-off purchase. These survive a lapsed subscription.
    public var ownedCosmetics: Set<String>
    public var starTotal: Int

    public init(
        hasRemoveAdsPurchase: Bool = false,
        pro: ProSubscriptionState = .notSubscribed,
        purchasedProducts: Set<StoreProductID> = [],
        ownedCosmetics: Set<String> = [],
        starTotal: Int = 0
    ) {
        self.hasRemoveAdsPurchase = hasRemoveAdsPurchase
        self.pro = pro
        self.purchasedProducts = purchasedProducts
        self.ownedCosmetics = ownedCosmetics
        self.starTotal = starTotal
    }

    // MARK: - Derived rules

    public var isPro: Bool { pro.grantsAccess }

    /// Ads are shown only to players who have neither bought them away nor
    /// subscribed. Anything else would be a refund request waiting to happen.
    public var showsAds: Bool { !hasRemoveAdsPurchase && !isPro }

    /// The Pro level track: bigger boards, more colours, wall cells.
    public var unlocksProTrack: Bool { isPro }

    public var hasUnlimitedHints: Bool { isPro }

    /// Pro doubles the soft-currency earn rate.
    public var gemMultiplier: Int { isPro ? 2 : 1 }

    /// Pro members get the monthly cosmetic drop as soon as it lands.
    public var unlocksExclusiveDrops: Bool { isPro }

    // MARK: - Cosmetics

    /// Owned outright, independent of any subscription.
    public func isOwnedOutright(_ cosmetic: Cosmetic) -> Bool {
        switch cosmetic.unlock {
        case .free:
            true
        case .gems:
            ownedCosmetics.contains(cosmetic.id)
        case .stars(let required):
            starTotal >= required
        case .purchase(let product):
            purchasedProducts.contains(product) || ownedCosmetics.contains(cosmetic.id)
        case .proSubscription:
            false
        }
    }

    /// Pro unlocks the whole cosmetic catalogue while it is active. Items
    /// bought with gems or money stay owned when it lapses; the rest revert.
    public func canUse(_ cosmetic: Cosmetic) -> Bool {
        isOwnedOutright(cosmetic) || isPro
    }

    public func canUse(cosmeticID: String) -> Bool {
        guard let cosmetic = CosmeticCatalog.cosmetic(id: cosmeticID) else { return false }
        return canUse(cosmetic)
    }

    public func lockReason(for cosmetic: Cosmetic) -> LockReason? {
        guard !canUse(cosmetic) else { return nil }
        switch cosmetic.unlock {
        case .free: return nil
        case .gems(let amount): return .needsGems(amount)
        case .stars(let amount): return .needsStars(amount)
        case .purchase(let product): return .needsPurchase(product)
        case .proSubscription: return .needsPro
        }
    }

    /// Replaces anything the player may no longer use with the category
    /// default. Called whenever entitlements change, which is what makes a
    /// lapsed subscription degrade gracefully instead of rendering a locked
    /// palette the player cannot change back.
    public func sanitized(_ equipped: EquippedCosmetics) -> EquippedCosmetics {
        var result = equipped
        for category in Cosmetic.Category.allCases where !canUse(cosmeticID: equipped.id(for: category)) {
            result.set(CosmeticCatalog.defaultID(for: category), for: category)
        }
        return result
    }

    /// Cosmetics the player would lose if Pro lapsed right now - used to be
    /// straight with people on the "manage subscription" screen instead of
    /// letting the loss surprise them.
    public var cosmeticsGrantedByPro: [Cosmetic] {
        guard isPro else { return [] }
        return CosmeticCatalog.all.filter { !isOwnedOutright($0) }
    }
}
