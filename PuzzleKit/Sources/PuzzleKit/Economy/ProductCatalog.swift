import Foundation

/// Everything the game sells, as a closed set of identifiers.
///
/// Product identifiers are declared here rather than as loose strings so that a
/// typo cannot silently break a purchase, and so the StoreKit configuration
/// file, App Store Connect and the paywall can be checked against one list.
public enum StoreProductID: String, CaseIterable, Codable, Sendable, Identifiable {

    /// One-off purchase that removes every ad, forever.
    case removeAds = "com.sabettaworks.LineFlowSW.removeads"

    /// Soft-currency packs. Gems only ever buy cosmetics and hints.
    case gemsPouch = "com.sabettaworks.LineFlowSW.gems.pouch"
    case gemsChest = "com.sabettaworks.LineFlowSW.gems.chest"
    case gemsVault = "com.sabettaworks.LineFlowSW.gems.vault"

    /// One-off cosmetic bundles, owned forever.
    case stylePackOrchid = "com.sabettaworks.LineFlowSW.style.orchid"
    case stylePackNeon = "com.sabettaworks.LineFlowSW.style.neon"

    /// Fieldweave Pro, the monthly and yearly subscription.
    case proMonthly = "com.sabettaworks.LineFlowSW.pro.monthly"
    case proYearly = "com.sabettaworks.LineFlowSW.pro.yearly"

    public var id: String { rawValue }
}

public enum ProductKind: String, Sendable, Codable {
    case consumable
    case nonConsumable
    case autoRenewable
}

public extension StoreProductID {

    var kind: ProductKind {
        switch self {
        case .gemsPouch, .gemsChest, .gemsVault:
            .consumable
        case .removeAds, .stylePackOrchid, .stylePackNeon:
            .nonConsumable
        case .proMonthly, .proYearly:
            .autoRenewable
        }
    }

    /// Gems granted on purchase, for consumables.
    var gemGrant: Int {
        switch self {
        case .gemsPouch: 500
        case .gemsChest: 1_500
        case .gemsVault: 4_000
        default: 0
        }
    }

    /// Cosmetic ids a purchase grants outright.
    var grantedCosmetics: [String] {
        switch self {
        case .stylePackOrchid: ["orchid"]
        case .stylePackNeon: ["comet", "starfield"]
        default: []
        }
    }

    var removesAds: Bool {
        switch self {
        case .removeAds, .proMonthly, .proYearly: true
        default: false
        }
    }

    var isSubscription: Bool { kind == .autoRenewable }

    var nameKey: String { "product.\(shortKey).name" }
    var descriptionKey: String { "product.\(shortKey).description" }

    private var shortKey: String {
        switch self {
        case .removeAds: "removeads"
        case .gemsPouch: "gems.pouch"
        case .gemsChest: "gems.chest"
        case .gemsVault: "gems.vault"
        case .stylePackOrchid: "style.orchid"
        case .stylePackNeon: "style.neon"
        case .proMonthly: "pro.monthly"
        case .proYearly: "pro.yearly"
        }
    }

    /// Display order inside its section of the store.
    var sortIndex: Int {
        switch self {
        case .removeAds: 0
        case .gemsPouch: 0
        case .gemsChest: 1
        case .gemsVault: 2
        case .stylePackOrchid: 0
        case .stylePackNeon: 1
        case .proMonthly: 0
        case .proYearly: 1
        }
    }
}

public enum ProductCatalog {

    /// The subscription group assigned by App Store Connect.
    ///
    /// This is account-specific, not something to invent: `status(for:)` looks
    /// the group up by this id, and a wrong one returns no status at all - so
    /// every subscriber would read as unsubscribed. `Products.storekit` carries
    /// the same value so the simulator answers the same question the same way.
    public static let subscriptionGroupID = "22339558"
    public static let subscriptionGroupName = "Fieldweave Pro"

    public static let allIdentifiers: [String] = StoreProductID.allCases.map(\.rawValue)

    public static let subscriptions: [StoreProductID] = StoreProductID.allCases
        .filter(\.isSubscription)
        .sorted { $0.sortIndex < $1.sortIndex }

    public static let consumables: [StoreProductID] = StoreProductID.allCases
        .filter { $0.kind == .consumable }
        .sorted { $0.sortIndex < $1.sortIndex }

    public static let oneOffUnlocks: [StoreProductID] = StoreProductID.allCases
        .filter { $0.kind == .nonConsumable }
        .sorted { $0.sortIndex < $1.sortIndex }

    public static func product(for identifier: String) -> StoreProductID? {
        StoreProductID(rawValue: identifier)
    }

    /// Gems a hint costs when the player has none left and does not want to
    /// watch a rewarded ad.
    public static let hintGemCost = 75
    /// Hints granted per rewarded video.
    public static let hintsPerRewardedAd = 1
    /// Gems granted per rewarded video, as an alternative reward.
    public static let gemsPerRewardedAd = 40
}
