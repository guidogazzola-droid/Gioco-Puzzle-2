import Testing
@testable import PuzzleKit

struct CosmeticCatalogTests {

    @Test("cosmetic ids are unique across the whole catalogue")
    func idsAreUnique() {
        let ids = CosmeticCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("every category has a free default that is actually free")
    func defaultsAreFree() {
        for category in Cosmetic.Category.allCases {
            let id = CosmeticCatalog.defaultID(for: category)
            let cosmetic = CosmeticCatalog.cosmetic(id: id)
            #expect(cosmetic != nil, "missing default for \(category.rawValue)")
            #expect(cosmetic?.category == category)
            #expect(cosmetic?.unlock == .free)
        }
    }

    @Test("every category has something to sell and something to earn")
    func everyCategoryHasAProgressionLadder() {
        func isEarnable(_ cosmetic: Cosmetic) -> Bool {
            switch cosmetic.unlock {
            case .gems, .stars: true
            case .free, .purchase, .proSubscription: false
            }
        }

        for category in Cosmetic.Category.allCases {
            let items = CosmeticCatalog.items(in: category)
            #expect(items.count >= 4, "\(category.rawValue) is too thin to feel like a collection")
            let hasProItem = items.contains { $0.unlock == .proSubscription }
            #expect(hasProItem, "\(category.rawValue) gives subscribers nothing")

            let hasEarnableItem = items.contains(where: isEarnable)
            #expect(hasEarnableItem, "\(category.rawValue) cannot be progressed toward by playing")
        }
    }

    @Test("a purchasable cosmetic is actually granted by the product it names")
    func purchaseUnlocksAreWiredUp() {
        for cosmetic in CosmeticCatalog.all {
            guard case .purchase(let product) = cosmetic.unlock else { continue }
            #expect(product.kind == .nonConsumable, "\(cosmetic.id) is sold as a subscription")
            #expect(product.grantedCosmetics.contains(cosmetic.id),
                    "\(product.rawValue) does not grant \(cosmetic.id)")
        }
    }

    @Test("every cosmetic a product grants exists in the catalogue")
    func productGrantsResolve() {
        for product in StoreProductID.allCases {
            for id in product.grantedCosmetics {
                #expect(CosmeticCatalog.cosmetic(id: id) != nil,
                        "\(product.rawValue) grants unknown cosmetic \(id)")
            }
        }
    }

    @Test("every palette can colour the biggest board the game can generate")
    func palettesCoverEveryColor() {
        let widest = (1...400).flatMap { level in
            LevelTrack.allCases.map { DifficultyCurve.parameters(level: level, track: $0).colors }
        }.max() ?? 0

        for cosmetic in CosmeticCatalog.palettes {
            let colors = CosmeticCatalog.colors(forPalette: cosmetic.id)
            #expect(colors.count >= widest,
                    "\(cosmetic.id) has \(colors.count) colours but boards need \(widest)")
            #expect(Set(colors).count == colors.count, "\(cosmetic.id) repeats a colour")
            for hex in colors {
                #expect(hex.count == 7 && hex.hasPrefix("#"), "malformed colour \(hex)")
            }
        }
    }

    @Test("colour lookup wraps instead of crashing")
    func colorLookupIsTotal() {
        #expect(!CosmeticCatalog.color(forPalette: "aurora", colorIndex: 0).isEmpty)
        #expect(!CosmeticCatalog.color(forPalette: "aurora", colorIndex: 999).isEmpty)
        #expect(!CosmeticCatalog.color(forPalette: "aurora", colorIndex: -3).isEmpty)
        // An unknown palette falls back rather than leaving the board blank.
        #expect(CosmeticCatalog.colors(forPalette: "nope")
                == CosmeticCatalog.colors(forPalette: CosmeticCatalog.defaultPalette))
    }

    @Test("star unlocks are reachable by playing the campaign")
    func starUnlocksAreReachable() {
        let required = CosmeticCatalog.all.compactMap { cosmetic -> Int? in
            if case .stars(let amount) = cosmetic.unlock { return amount }
            return nil
        }
        #expect(!required.isEmpty)
        // The first chapter alone is worth 90 stars, so nothing gated on stars
        // should sit beyond a couple of chapters of play.
        #expect(required.max()! <= ChapterCatalog.levelsPerChapter * 3 * 2)
        #expect(CosmeticCatalog.starUnlocks(upTo: 0).isEmpty)
        #expect(CosmeticCatalog.starUnlocks(upTo: required.max()!).count == required.count)
    }

    @Test("shop previews always have swatch colours to draw")
    func swatchesArePresent() {
        for cosmetic in CosmeticCatalog.all {
            #expect(!cosmetic.swatch.isEmpty, "\(cosmetic.id) has no preview colours")
        }
    }
}

struct ProductCatalogTests {

    @Test("product identifiers are unique and namespaced")
    func identifiersAreWellFormed() {
        let ids = StoreProductID.allCases.map(\.rawValue)
        #expect(Set(ids).count == ids.count)
        for id in ids {
            #expect(id.hasPrefix("com.sabettaworks.LineFlowSW."))
        }
    }

    @Test("each product kind holds exactly the products it should")
    func kindsArePartitioned() {
        let subscriptionsOnly = ProductCatalog.subscriptions.allSatisfy { $0.kind == .autoRenewable }
        let consumablesOnly = ProductCatalog.consumables.allSatisfy { $0.kind == .consumable }
        let unlocksOnly = ProductCatalog.oneOffUnlocks.allSatisfy { $0.kind == .nonConsumable }
        #expect(subscriptionsOnly)
        #expect(consumablesOnly)
        #expect(unlocksOnly)
        let total = ProductCatalog.subscriptions.count
            + ProductCatalog.consumables.count
            + ProductCatalog.oneOffUnlocks.count
        #expect(total == StoreProductID.allCases.count)
    }

    @Test("only gem packs grant gems, and bigger packs grant more")
    func gemPacksScale() {
        for product in StoreProductID.allCases where product.kind != .consumable {
            #expect(product.gemGrant == 0, "\(product.rawValue) should not grant gems")
        }
        let grants = ProductCatalog.consumables.map(\.gemGrant)
        #expect(grants == grants.sorted())
        let allPositive = grants.allSatisfy { $0 > 0 }
        #expect(allPositive)
    }

    @Test("everything that should remove ads does")
    func adRemovalIsConsistent() {
        #expect(StoreProductID.removeAds.removesAds)
        let subscriptionsRemoveAds = ProductCatalog.subscriptions.allSatisfy(\.removesAds)
        #expect(subscriptionsRemoveAds)
        #expect(!StoreProductID.gemsPouch.removesAds)
        #expect(!StoreProductID.stylePackNeon.removesAds)
    }

    @Test("localisation keys are distinct per product")
    func localisationKeysAreDistinct() {
        let names = StoreProductID.allCases.map(\.nameKey)
        #expect(Set(names).count == names.count)
        let descriptions = StoreProductID.allCases.map(\.descriptionKey)
        #expect(Set(descriptions).count == descriptions.count)
    }
}
