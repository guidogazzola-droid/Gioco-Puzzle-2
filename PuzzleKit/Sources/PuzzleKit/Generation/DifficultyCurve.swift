import Foundation

/// The two level tracks the game ships with.
///
/// `free` is the endless track every player can play. `pro` is the harder track
/// gated behind the Fieldweave Pro subscription: bigger boards, more colours
/// and wall cells, which is the mechanical difference the subscription sells.
public enum LevelTrack: String, Codable, Sendable, CaseIterable, Identifiable {
    case free
    case pro

    public var id: String { rawValue }

    /// Mixed into the generator seed so the two tracks never share a board.
    var seedSalt: UInt64 {
        switch self {
        case .free: 0x4652_4545
        case .pro:  0x5052_4F00
        }
    }
}

/// The shape of a single generated level.
public struct LevelParameters: Hashable, Sendable {
    public let width: Int
    public let height: Int
    public let colors: Int
    public let blocked: Int
    public let isBoss: Bool
    public let isBreather: Bool

    public var cells: Int { width * height }
    public var playableCells: Int { cells - blocked }
}

/// Maps a level number onto the board it should produce.
///
/// A designed stage table beats a linear ramp: it lets the curve flatten at the
/// points where hybrid-casual funnels lose players (the first ten levels, and
/// again around level 30) instead of climbing straight through them.
public enum DifficultyCurve {

    /// `(minLevel, side, colors)` - the last entry whose `minLevel` is reached wins.
    static let freeStages: [(minLevel: Int, side: Int, colors: Int)] = [
        (1, 5, 3), (7, 5, 4), (15, 6, 4), (25, 6, 5), (37, 7, 5),
        (51, 7, 6), (67, 8, 6), (85, 8, 7), (105, 9, 7), (130, 9, 8)
    ]

    static let proStages: [(minLevel: Int, side: Int, colors: Int)] = [
        (1, 7, 5), (9, 8, 6), (19, 8, 7), (31, 9, 8), (45, 10, 9),
        (61, 10, 10), (79, 11, 11), (99, 12, 12), (121, 12, 13)
    ]

    /// Board silhouette cycle, applied on top of the stage table so late levels
    /// keep changing shape after the size curve has plateaued.
    static let shapeCycle: [(dw: Int, dh: Int)] = [
        (0, 0), (0, -1), (0, 0), (-1, 0), (1, -1), (0, 0)
    ]

    static let maximumSide = 13

    /// Every tenth level is a boss: one size step up and one extra colour.
    public static func isBoss(level: Int) -> Bool { level % 10 == 0 }

    /// Every seventh non-boss level is a deliberate breather, so failure
    /// streaks do not stack.
    public static func isBreather(level: Int) -> Bool {
        level % 7 == 0 && !isBoss(level: level)
    }

    public static func parameters(level: Int, track: LevelTrack) -> LevelParameters {
        let level = max(1, level)
        let boss = isBoss(level: level)
        let breather = isBreather(level: level)

        let stages = track == .pro ? proStages : freeStages
        var side = stages[0].side
        var colors = stages[0].colors
        for stage in stages where level >= stage.minLevel {
            side = stage.side
            colors = stage.colors
        }

        // Walls stay a Pro-track differentiator.
        var blockedPercent = track == .pro ? min(10, max(0, (level - 15) / 8)) : 0

        let shape = shapeCycle[level % shapeCycle.count]
        var width = max(5, side + shape.dw)
        var height = max(5, side + shape.dh)

        if boss {
            width = min(width + 1, maximumSide)
            height = min(height + 1, maximumSide)
            colors += 1
        }
        if breather {
            colors = max(3, colors - 2)
            blockedPercent = 0
        }

        let cells = width * height
        // Never wall off so much that the remaining board becomes trivial.
        let blocked = min(cells * blockedPercent / 100, max(0, cells / 6))
        let playable = cells - blocked

        // Every colour needs two cells, and the board needs slack to stay solvable.
        colors = max(3, min(colors, (playable / 2) - 1))

        return LevelParameters(
            width: width,
            height: height,
            colors: colors,
            blocked: blocked,
            isBoss: boss,
            isBreather: breather
        )
    }

    /// Turns per playable cell the generator aims for: low reads as a clean
    /// tutorial board, high as a knotted late-game board.
    public static func targetTwistiness(level: Int, track: LevelTrack) -> Double {
        let base = track == .free ? 0.18 : 0.34
        let cap = track == .free ? 0.52 : 0.62
        let growth = min(1.0, Double(max(0, level - 1)) / 60.0)
        return base + (cap - base) * growth
    }
}
