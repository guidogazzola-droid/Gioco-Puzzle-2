import Foundation

/// One purely cosmetic item. Nothing here changes difficulty or progression -
/// that separation is deliberate and is what keeps the store from reading as
/// pay-to-win.
public struct Cosmetic: Identifiable, Hashable, Sendable, Codable {

    public enum Category: String, Codable, Sendable, CaseIterable, Identifiable {
        case palette
        case trail
        case background
        case nodeShape

        public var id: String { rawValue }

        public var titleKey: String { "cosmetic.category.\(rawValue)" }
    }

    /// How the item is obtained.
    public enum Unlock: Hashable, Sendable, Codable {
        /// Available from the first launch.
        case free
        /// Bought with the soft currency earned by playing.
        case gems(Int)
        /// Awarded for reaching a star total.
        case stars(Int)
        /// A one-off App Store purchase, owned forever.
        case purchase(StoreProductID)
        /// Included with an active Fieldweave Pro subscription.
        case proSubscription
    }

    public let id: String
    public let category: Category
    public let nameKey: String
    public let unlock: Unlock
    public let sortIndex: Int
    /// Two or three hex colours used to draw the shop preview tile.
    public let swatch: [String]

    public init(
        id: String,
        category: Category,
        nameKey: String,
        unlock: Unlock,
        sortIndex: Int,
        swatch: [String]
    ) {
        self.id = id
        self.category = category
        self.nameKey = nameKey
        self.unlock = unlock
        self.sortIndex = sortIndex
        self.swatch = swatch
    }

    public var isProExclusive: Bool { unlock == .proSubscription }
}

/// Every cosmetic the game ships with.
public enum CosmeticCatalog {

    public static let defaultPalette = "aurora"
    public static let defaultTrail = "solid"
    public static let defaultBackground = "slate"
    public static let defaultNodeShape = "dot"

    public static let all: [Cosmetic] = palettes + trails + backgrounds + nodeShapes

    // MARK: - Palettes

    public static let palettes: [Cosmetic] = [
        Cosmetic(id: "aurora", category: .palette, nameKey: "cosmetic.palette.aurora",
                 unlock: .free, sortIndex: 0, swatch: swatch("aurora")),
        Cosmetic(id: "tide", category: .palette, nameKey: "cosmetic.palette.tide",
                 unlock: .stars(15), sortIndex: 1, swatch: swatch("tide")),
        Cosmetic(id: "ember", category: .palette, nameKey: "cosmetic.palette.ember",
                 unlock: .gems(250), sortIndex: 2, swatch: swatch("ember")),
        Cosmetic(id: "circuit", category: .palette, nameKey: "cosmetic.palette.circuit",
                 unlock: .gems(400), sortIndex: 3, swatch: swatch("circuit")),
        Cosmetic(id: "orchid", category: .palette, nameKey: "cosmetic.palette.orchid",
                 unlock: .purchase(.stylePackOrchid), sortIndex: 4, swatch: swatch("orchid")),
        Cosmetic(id: "glacier", category: .palette, nameKey: "cosmetic.palette.glacier",
                 unlock: .proSubscription, sortIndex: 5, swatch: swatch("glacier")),
        Cosmetic(id: "dusk", category: .palette, nameKey: "cosmetic.palette.dusk",
                 unlock: .proSubscription, sortIndex: 6, swatch: swatch("dusk")),
        Cosmetic(id: "nebula", category: .palette, nameKey: "cosmetic.palette.nebula",
                 unlock: .proSubscription, sortIndex: 7, swatch: swatch("nebula"))
    ]

    // MARK: - Trails

    public static let trails: [Cosmetic] = [
        Cosmetic(id: "solid", category: .trail, nameKey: "cosmetic.trail.solid",
                 unlock: .free, sortIndex: 0, swatch: ["#8E9BB3", "#5C6980"]),
        Cosmetic(id: "glow", category: .trail, nameKey: "cosmetic.trail.glow",
                 unlock: .gems(200), sortIndex: 1, swatch: ["#5EE7FF", "#1B7FA8"]),
        Cosmetic(id: "ribbon", category: .trail, nameKey: "cosmetic.trail.ribbon",
                 unlock: .stars(60), sortIndex: 2, swatch: ["#FFCB6B", "#FF7A59"]),
        Cosmetic(id: "comet", category: .trail, nameKey: "cosmetic.trail.comet",
                 unlock: .purchase(.stylePackNeon), sortIndex: 3, swatch: ["#FF61D2", "#7A4BFF"]),
        Cosmetic(id: "plasma", category: .trail, nameKey: "cosmetic.trail.plasma",
                 unlock: .proSubscription, sortIndex: 4, swatch: ["#B4FF3D", "#00C2A8"])
    ]

    // MARK: - Backgrounds

    public static let backgrounds: [Cosmetic] = [
        Cosmetic(id: "slate", category: .background, nameKey: "cosmetic.background.slate",
                 unlock: .free, sortIndex: 0, swatch: ["#151A24", "#232B3A"]),
        Cosmetic(id: "mesh", category: .background, nameKey: "cosmetic.background.mesh",
                 unlock: .stars(40), sortIndex: 1, swatch: ["#101B2E", "#1E3A5F"]),
        Cosmetic(id: "drift", category: .background, nameKey: "cosmetic.background.drift",
                 unlock: .gems(500), sortIndex: 2, swatch: ["#221436", "#4A1E63"]),
        Cosmetic(id: "starfield", category: .background, nameKey: "cosmetic.background.starfield",
                 unlock: .purchase(.stylePackNeon), sortIndex: 3, swatch: ["#05070F", "#1B2A4A"]),
        Cosmetic(id: "liquid", category: .background, nameKey: "cosmetic.background.liquid",
                 unlock: .proSubscription, sortIndex: 4, swatch: ["#032B2B", "#0A5C52"])
    ]

    // MARK: - Node shapes

    public static let nodeShapes: [Cosmetic] = [
        Cosmetic(id: "dot", category: .nodeShape, nameKey: "cosmetic.node.dot",
                 unlock: .free, sortIndex: 0, swatch: ["#FFFFFF"]),
        Cosmetic(id: "hex", category: .nodeShape, nameKey: "cosmetic.node.hex",
                 unlock: .stars(25), sortIndex: 1, swatch: ["#FFFFFF"]),
        Cosmetic(id: "gem", category: .nodeShape, nameKey: "cosmetic.node.gem",
                 unlock: .gems(300), sortIndex: 2, swatch: ["#FFFFFF"]),
        Cosmetic(id: "bloom", category: .nodeShape, nameKey: "cosmetic.node.bloom",
                 unlock: .proSubscription, sortIndex: 3, swatch: ["#FFFFFF"])
    ]

    // MARK: - Lookup

    public static func cosmetic(id: String) -> Cosmetic? {
        all.first { $0.id == id }
    }

    public static func items(in category: Cosmetic.Category) -> [Cosmetic] {
        all.filter { $0.category == category }.sorted { $0.sortIndex < $1.sortIndex }
    }

    public static func defaultID(for category: Cosmetic.Category) -> String {
        switch category {
        case .palette: defaultPalette
        case .trail: defaultTrail
        case .background: defaultBackground
        case .nodeShape: defaultNodeShape
        }
    }

    /// Colours for a palette id, falling back to the default palette so a
    /// missing or renamed id can never leave the board unpainted.
    public static func colors(forPalette id: String) -> [String] {
        paletteColors[id] ?? paletteColors[defaultPalette] ?? ["#FFFFFF"]
    }

    /// The colour a given flow is drawn in, wrapping if a board somehow has
    /// more colours than the palette defines.
    public static func color(forPalette id: String, colorIndex: Int) -> String {
        let palette = colors(forPalette: id)
        guard !palette.isEmpty else { return "#FFFFFF" }
        return palette[((colorIndex % palette.count) + palette.count) % palette.count]
    }

    /// Cosmetics unlocked purely by playing, given a star total. Used to show
    /// "unlocked!" toasts and to compute what the player already has.
    public static func starUnlocks(upTo stars: Int) -> [Cosmetic] {
        all.filter {
            if case .stars(let required) = $0.unlock { return stars >= required }
            return false
        }
    }

    private static func swatch(_ paletteID: String) -> [String] {
        let colors = paletteColors[paletteID] ?? []
        guard colors.count >= 9 else { return colors }
        return [colors[1], colors[5], colors[9]]
    }
}
