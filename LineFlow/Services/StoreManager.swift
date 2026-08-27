import Foundation
import Observation
import StoreKit
import PuzzleKit

/// All StoreKit traffic in one place.
///
/// It owns only what the App Store knows: which non-consumables are owned and
/// where the subscription stands. Star totals and gem-bought cosmetics live in
/// the save file, and `AppServices` merges the two into the `Entitlements`
/// value the rest of the game reads.
@MainActor
@Observable
final class StoreManager {

    enum PurchaseOutcome: Equatable {
        case purchased
        /// Waiting on Ask to Buy or an SCA challenge - the transaction will
        /// arrive later through `Transaction.updates`.
        case pending
        case cancelled
        case failed(String)
    }

    private(set) var products: [Product] = []
    private(set) var hasRemoveAdsPurchase = false
    private(set) var proState: ProSubscriptionState = .notSubscribed
    private(set) var purchasedProducts: Set<StoreProductID> = []
    private(set) var isLoadingProducts = false
    private(set) var productLoadFailed = false
    private(set) var isRestoring = false

    /// Called when a gem pack is bought, so the profile can be credited.
    var onConsumablePurchased: ((StoreProductID) -> Void)?
    /// Called when a permanent unlock is bought or restored.
    var onUnlockPurchased: ((StoreProductID) -> Void)?

    private var updatesTask: Task<Void, Never>?

    // MARK: - Lifecycle

    /// Starts the transaction listener before anything else can produce one.
    /// Missing an update means a player who paid does not get their content.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    // MARK: - Catalogue

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: ProductCatalog.allIdentifiers)
            productLoadFailed = products.isEmpty
        } catch {
            productLoadFailed = true
        }
    }

    func product(for id: StoreProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    /// Localised price, or `nil` while the catalogue is still loading. Never
    /// hard-code a price: App Store pricing is per storefront.
    func displayPrice(for id: StoreProductID) -> String? {
        product(for: id)?.displayPrice
    }

    /// "€4,99 / month" style string for the paywall.
    func subscriptionPriceLine(for id: StoreProductID) -> String? {
        guard let product = product(for: id),
              let period = product.subscription?.subscriptionPeriod
        else { return displayPrice(for: id) }
        return "\(product.displayPrice) / \(Self.periodName(period))"
    }

    static func periodName(_ period: Product.SubscriptionPeriod) -> String {
        let key: String
        switch period.unit {
        case .day: key = period.value == 7 ? "period.week" : "period.day"
        case .week: key = "period.week"
        case .month: key = "period.month"
        case .year: key = "period.year"
        @unknown default: key = "period.month"
        }
        return NSLocalizedString(key, comment: "Subscription period")
    }

    // MARK: - Buying

    func purchase(_ id: StoreProductID) async -> PurchaseOutcome {
        guard let product = product(for: id) else {
            return .failed(NSLocalizedString("store.error.unavailable", comment: ""))
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard let transaction = Self.verified(verification) else {
                    return .failed(NSLocalizedString("store.error.unverified", comment: ""))
                }
                grant(transaction)
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed(NSLocalizedString("store.error.generic", comment: ""))
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Apple requires a visible restore control for non-consumables.
    @discardableResult
    func restorePurchases() async -> Bool {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return true
        } catch {
            await refreshEntitlements()
            return false
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var owned: Set<StoreProductID> = []
        var removeAds = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = Self.verified(result),
                  let id = StoreProductID(rawValue: transaction.productID),
                  transaction.revocationDate == nil
            else { continue }
            if let expiry = transaction.expirationDate, expiry < Date() { continue }

            owned.insert(id)
            if id == .removeAds { removeAds = true }
            // Re-grant permanent unlocks so a reinstall restores the cosmetics
            // a player already paid for.
            if id.kind == .nonConsumable { onUnlockPurchased?(id) }
        }

        purchasedProducts = owned
        hasRemoveAdsPurchase = removeAds
        proState = await resolveProState()
    }

    private func resolveProState() async -> ProSubscriptionState {
        do {
            let statuses = try await Product.SubscriptionInfo.status(
                for: ProductCatalog.subscriptionGroupID
            )
            // Family Sharing can report several statuses; the player should get
            // the best one they are entitled to.
            let resolved = statuses.compactMap(Self.state(from:))
            return resolved.max { Self.rank($0) < Self.rank($1) } ?? .notSubscribed
        } catch {
            return .notSubscribed
        }
    }

    private static func state(from status: Product.SubscriptionInfo.Status) -> ProSubscriptionState? {
        guard let transaction = verified(status.transaction),
              let renewal = verified(status.renewalInfo)
        else { return nil }

        let expiry = transaction.expirationDate
        let isTrial = transaction.offer?.type == .introductory

        switch status.state {
        case .subscribed:
            return .active(expiresAt: expiry, isTrial: isTrial, willAutoRenew: renewal.willAutoRenew)
        case .inGracePeriod:
            return .gracePeriod(expiresAt: expiry)
        case .inBillingRetryPeriod:
            return .billingRetry
        case .revoked:
            return .revoked
        case .expired:
            return .expired(at: expiry)
        default:
            return .notSubscribed
        }
    }

    /// Ordering used to pick the most favourable of several statuses.
    private static func rank(_ state: ProSubscriptionState) -> Int {
        switch state {
        case .active: 5
        case .gracePeriod: 4
        case .billingRetry: 3
        case .expired: 2
        case .revoked: 1
        case .notSubscribed: 0
        }
    }

    // MARK: - Internals

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = Self.verified(result) else { return }
        if transaction.revocationDate == nil {
            grant(transaction)
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func grant(_ transaction: Transaction) {
        guard let id = StoreProductID(rawValue: transaction.productID) else { return }
        switch id.kind {
        case .consumable:
            onConsumablePurchased?(id)
        case .nonConsumable, .autoRenewable:
            onUnlockPurchased?(id)
        }
    }

    /// Only Apple-signed transactions are ever acted on.
    private static func verified<T>(_ result: VerificationResult<T>) -> T? {
        switch result {
        case .verified(let safe): return safe
        case .unverified: return nil
        }
    }
}
