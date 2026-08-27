import Foundation
import Testing
@testable import PrismFlow
@testable import PuzzleKit

/// Tests for the app layer: the parts that sit between PuzzleKit and SwiftUI.
///
/// PuzzleKit has its own suite; what is checked here is the wiring - the save
/// file, the geometry the drag gesture depends on, and the service that merges
/// App Store facts with save-file facts.
@MainActor
struct ProfileStoreTests {

    private func temporaryStore() -> (ProfileStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismflow-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("profile.json")
        return (ProfileStore(fileURL: url), url)
    }

    @Test("a store with no file on disk starts from a fresh profile")
    func startsFresh() {
        let (store, url) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(store.profile == PlayerProfile())
        #expect(!store.didRecoverFromCorruptSave)
    }

    @Test("a flushed profile is read back by the next store")
    func roundTripsThroughDisk() {
        let (store, url) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.update { $0.gems = 1_234 }
        store.update { $0.free.highestUnlocked = 9 }
        store.flush()

        let reopened = ProfileStore(fileURL: url)
        #expect(reopened.profile.gems == 1_234)
        #expect(reopened.profile.free.highestUnlocked == 9)
    }

    @Test("an unreadable save is quarantined, never silently overwritten")
    func corruptSaveIsQuarantined() throws {
        let (_, url) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{ this is not json".utf8).write(to: url)

        let store = ProfileStore(fileURL: url)
        #expect(store.didRecoverFromCorruptSave)
        #expect(store.profile == PlayerProfile())
        // The player's original bytes are still on disk for support to recover.
        #expect(FileManager.default.fileExists(atPath: url.appendingPathExtension("corrupt").path))
    }

    @Test("the save is written atomically as valid JSON")
    func writesValidJSON() throws {
        let (store, url) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        store.update { $0.gems = 42 }
        store.flush()

        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["gems"] as? Int == 42)
    }
}

struct BoardGeometryTests {

    @Test("the board is centred and square within its space")
    func layoutIsCentred() {
        let geometry = BoardGeometry(size: CGSize(width: 400, height: 300), columns: 5, rows: 5)
        #expect(geometry.cellSize > 0)
        #expect(geometry.boardRect.width == geometry.boardRect.height)
        let leading = geometry.boardRect.minX
        let trailing = 400 - geometry.boardRect.maxX
        #expect(abs(leading - trailing) < 0.001)
    }

    @Test("every cell round-trips from centre back to itself")
    func hitTestingIsExact() {
        let geometry = BoardGeometry(size: CGSize(width: 380, height: 500), columns: 7, rows: 9)
        for y in 0..<9 {
            for x in 0..<7 {
                let cell = Coordinate(x, y)
                #expect(geometry.coordinate(at: geometry.center(of: cell)) == cell)
            }
        }
    }

    @Test("touches outside the board are rejected rather than clamped")
    func outOfBoundsTouchesReturnNil() {
        let geometry = BoardGeometry(size: CGSize(width: 300, height: 300), columns: 5, rows: 5)
        #expect(geometry.coordinate(at: CGPoint(x: -50, y: 10)) == nil)
        #expect(geometry.coordinate(at: CGPoint(x: 10, y: -50)) == nil)
        #expect(geometry.coordinate(at: CGPoint(x: 1_000, y: 150)) == nil)
        #expect(geometry.coordinate(at: CGPoint(x: 150, y: 1_000)) == nil)
    }

    @Test("a fast drag is filled in with a contiguous route")
    func routeIsContiguous() {
        let cases: [(Coordinate, Coordinate)] = [
            (Coordinate(0, 0), Coordinate(3, 0)),
            (Coordinate(0, 0), Coordinate(0, 4)),
            (Coordinate(1, 1), Coordinate(4, 3)),
            (Coordinate(4, 3), Coordinate(1, 1)),
            (Coordinate(2, 5), Coordinate(0, 0))
        ]
        for (start, end) in cases {
            let route = BoardGeometry.route(from: start, to: end)
            #expect(route.last == end)
            var previous = start
            for step in route {
                #expect(previous.isAdjacent(to: step), "\(previous) -> \(step) is not one step")
                previous = step
            }
        }
    }

    @Test("a route to the current cell is empty")
    func routeToSelfIsEmpty() {
        #expect(BoardGeometry.route(from: Coordinate(2, 2), to: Coordinate(2, 2)).isEmpty)
    }

    @Test("a degenerate size does not produce an invalid layout")
    func handlesZeroSize() {
        let geometry = BoardGeometry(size: .zero, columns: 5, rows: 5)
        #expect(geometry.cellSize >= 1)
        #expect(geometry.columns == 5)
    }
}

@MainActor
struct AppServicesTests {

    private func services() -> AppServices {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismflow-services-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("profile.json")
        return AppServices(profileStore: ProfileStore(fileURL: url))
    }

    @Test("entitlements merge App Store facts with save-file facts")
    func entitlementsMergeBothSources() {
        let services = services()
        services.profileStore.update { profile in
            profile.ownedCosmetics = ["ember"]
            profile.free.register(LevelOutcome(
                level: 1, track: .free, moves: 3, par: 3, seconds: 10,
                hintsUsed: 0, stars: 3, gems: 10, isFirstClear: true
            ))
        }
        #expect(services.entitlements.ownedCosmetics == ["ember"])
        #expect(services.entitlements.starTotal == 3)
        #expect(services.entitlements.showsAds, "no purchase has been made")
    }

    @Test("a cosmetic can only be bought with gems the player has")
    func gemPurchasesAreGuarded() {
        let services = services()
        let ember = CosmeticCatalog.cosmetic(id: "ember")!

        #expect(!services.buyWithGems(ember), "should not be affordable at zero gems")
        #expect(!services.entitlements.canUse(ember))

        services.profileStore.update { $0.gems = 250 }
        #expect(services.buyWithGems(ember))
        #expect(services.profile.gems == 0)
        #expect(services.entitlements.canUse(ember))
        #expect(services.isEquipped(ember), "buying a style should also equip it")
    }

    @Test("a locked cosmetic cannot be equipped by a stale view")
    func equippingRespectsEntitlements() {
        let services = services()
        let glacier = CosmeticCatalog.cosmetic(id: "glacier")!
        services.equip(glacier)
        #expect(services.profile.equipped.palette == CosmeticCatalog.defaultPalette)
    }

    @Test("hints are spent, and never go negative")
    func hintSpending() {
        let services = services()
        services.profileStore.update { $0.hints = 1 }
        #expect(services.hasFreeHint)
        #expect(services.consumeHint())
        #expect(!services.hasFreeHint)
        #expect(!services.consumeHint())

        services.profileStore.update { $0.gems = ProductCatalog.hintGemCost }
        #expect(services.buyHintWithGems())
        #expect(services.profile.hints == 1)
        #expect(services.profile.gems == 0)
        #expect(!services.buyHintWithGems())
    }

    @Test("finishing a level records it and pays out once")
    func finishingALevel() {
        let services = services()
        var engine = PuzzleEngine(blueprint: LevelGenerator.generate(level: 1, track: .free))
        for path in engine.blueprint.solution {
            engine.beginDrag(at: path[0])
            for cell in path.dropFirst() { engine.extendDrag(to: cell) }
            engine.endDrag()
        }
        #expect(engine.isSolved)

        let outcome = services.finish(engine: engine, seconds: 30, track: .free)
        #expect(outcome.stars == 3)
        #expect(services.profile.free.highestUnlocked == 2)
        #expect(services.profile.gems == outcome.gems)

        let replay = services.finish(engine: engine, seconds: 30, track: .free)
        #expect(!replay.isFirstClear)
        #expect(replay.gems < outcome.gems, "a replay must pay less than a first clear")
    }

    @Test("resetting progress never touches what the player paid for")
    func resetKeepsPurchases() {
        let services = services()
        services.profileStore.update { profile in
            profile.gems = 900
            profile.ownedCosmetics = ["ember", "glow"]
            profile.free.highestUnlocked = 42
            profile.settings.hapticsEnabled = false
        }
        services.resetProgress()

        #expect(services.profile.free.highestUnlocked == 1)
        #expect(services.profile.gems == 0)
        #expect(services.profile.ownedCosmetics == ["ember", "glow"], "bought styles survive a reset")
        #expect(!services.profile.settings.hapticsEnabled, "settings survive a reset")
    }

    @Test("the theme falls back when a skin is no longer entitled")
    func themeIsAlwaysDrawable() {
        let services = services()
        services.profileStore.update { $0.equipped.palette = "nebula" }  // Pro only
        #expect(services.theme.paletteID == CosmeticCatalog.defaultPalette)
        #expect(services.theme.colors.count >= 14)
    }
}

struct GameThemeTests {

    @Test("every cosmetic id in the catalogue resolves to something drawable")
    func allCosmeticsResolve() {
        for palette in CosmeticCatalog.palettes {
            var equipped = EquippedCosmetics()
            equipped.palette = palette.id
            #expect(GameTheme.resolve(equipped).colors.count >= 14)
        }
        for trail in CosmeticCatalog.trails {
            #expect(GameTheme.TrailStyle(rawValue: trail.id) != nil, "no renderer for trail \(trail.id)")
        }
        for background in CosmeticCatalog.backgrounds {
            #expect(GameTheme.BackgroundStyle(rawValue: background.id) != nil,
                    "no renderer for backdrop \(background.id)")
        }
        for node in CosmeticCatalog.nodeShapes {
            #expect(GameTheme.NodeShape(rawValue: node.id) != nil, "no renderer for node \(node.id)")
        }
    }

    @Test("an unknown cosmetic id degrades instead of crashing")
    func unknownIdsFallBack() {
        var equipped = EquippedCosmetics()
        equipped.palette = "nope"
        equipped.trail = "nope"
        equipped.background = "nope"
        equipped.nodeShape = "nope"
        let theme = GameTheme.resolve(equipped)
        #expect(theme.trail == .solid)
        #expect(theme.background == .slate)
        #expect(theme.node == .dot)
        #expect(!theme.colors.isEmpty)
    }

    @Test("colour lookup wraps for any index")
    func colorLookupIsTotal() {
        let theme = GameTheme.preview
        #expect(theme.color(for: 0) == theme.colors[0])
        #expect(theme.color(for: theme.colors.count) == theme.colors[0])
        #expect(theme.color(for: -1) == theme.colors[theme.colors.count - 1])
    }

    @Test("colour-blind glyphs are distinct for every colour a board can have")
    func glyphsAreDistinct() {
        let theme = GameTheme.preview
        let glyphs = (0..<14).map { theme.glyph(for: $0) }
        #expect(Set(glyphs).count == 14)
    }
}
