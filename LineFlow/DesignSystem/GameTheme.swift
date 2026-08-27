import SwiftUI
import PuzzleKit

/// Turns the player's equipped cosmetics into the concrete values the board
/// renderer draws with.
///
/// Cosmetics are ids in PuzzleKit and pixels here; this is the one place the
/// two meet, so adding a skin never means touching the renderer.
struct GameTheme: Equatable {

    enum TrailStyle: String {
        case solid, glow, ribbon, comet, plasma

        /// Fraction of the cell a trail occupies.
        var thickness: CGFloat {
            switch self {
            case .solid: 0.42
            case .glow: 0.40
            case .ribbon: 0.50
            case .comet: 0.38
            case .plasma: 0.46
            }
        }

        /// Radius of the halo drawn behind the trail, in cell fractions.
        var glowRadius: CGFloat {
            switch self {
            case .solid: 0
            case .glow: 0.30
            case .ribbon: 0.10
            case .comet: 0.22
            case .plasma: 0.36
            }
        }

        var drawsHighlight: Bool {
            switch self {
            case .ribbon, .plasma, .comet: true
            case .solid, .glow: false
            }
        }
    }

    enum NodeShape: String {
        case dot, hex, gem, bloom
    }

    enum BackgroundStyle: String {
        case slate, mesh, drift, starfield, liquid

        var colors: [Color] {
            switch self {
            case .slate: [Color(hex: "#151A24"), Color(hex: "#232B3A")]
            case .mesh: [Color(hex: "#101B2E"), Color(hex: "#1E3A5F")]
            case .drift: [Color(hex: "#221436"), Color(hex: "#4A1E63")]
            case .starfield: [Color(hex: "#05070F"), Color(hex: "#1B2A4A")]
            case .liquid: [Color(hex: "#032B2B"), Color(hex: "#0A5C52")]
            }
        }

        /// Whether the background draws its own animated decoration.
        var isAnimated: Bool {
            switch self {
            case .slate, .mesh: false
            case .drift, .starfield, .liquid: true
            }
        }
    }

    let paletteID: String
    let colors: [Color]
    let trail: TrailStyle
    let node: NodeShape
    let background: BackgroundStyle

    static func resolve(_ equipped: EquippedCosmetics) -> GameTheme {
        GameTheme(
            paletteID: equipped.palette,
            colors: CosmeticCatalog.colors(forPalette: equipped.palette).map { Color(hex: $0) },
            trail: TrailStyle(rawValue: equipped.trail) ?? .solid,
            node: NodeShape(rawValue: equipped.nodeShape) ?? .dot,
            background: BackgroundStyle(rawValue: equipped.background) ?? .slate
        )
    }

    static let preview = GameTheme.resolve(EquippedCosmetics())

    /// Never traps: a board with more colours than the palette wraps around.
    func color(for index: Int) -> Color {
        guard !colors.isEmpty else { return .white }
        return colors[((index % colors.count) + colors.count) % colors.count]
    }

    /// Distinct glyphs drawn on endpoints when colour-blind assist is on, so
    /// pairs can be matched by shape as well as by hue.
    static let assistGlyphs = Array("ABCDEFGHIJKLMN")

    func glyph(for index: Int) -> String {
        let glyphs = Self.assistGlyphs
        guard !glyphs.isEmpty else { return "" }
        return String(glyphs[((index % glyphs.count) + glyphs.count) % glyphs.count])
    }
}

/// Surface colours shared by every screen, independent of the equipped skin.
enum Ink {
    static let primary = Color(hex: "#F2F5FA")
    static let secondary = Color(hex: "#9AA6BC")
    static let card = Color(hex: "#1B2230")
    static let cardRaised = Color(hex: "#232C3E")
    static let stroke = Color(hex: "#33405A")
    static let accent = Color(hex: "#5EE7FF")
    static let gold = Color(hex: "#FFCB6B")
    static let pro = Color(hex: "#B478FF")
    static let danger = Color(hex: "#FF6B6B")
}
