import Foundation

/// The shape and density of one cubical level.
public struct CubeLevelParameters: Hashable, Sendable {
    public let side: Int
    public let activeFaces: [CubeFace]
    public let colors: Int
    public let blocked: Int
    public let isBoss: Bool
    public let isBreather: Bool

    public var cells: Int { side * side * activeFaces.count }
    public var playableCells: Int { cells - blocked }
}

/// Progresses from a two-face corner to the complete six-face instrument.
public enum CubeDifficultyCurve {

    private struct Stage {
        let minLevel: Int
        let side: Int
        let faces: Int
        let colors: Int
    }

    private static let freeStages = [
        Stage(minLevel: 1, side: 3, faces: 2, colors: 3),
        Stage(minLevel: 5, side: 3, faces: 3, colors: 4),
        Stage(minLevel: 12, side: 3, faces: 4, colors: 5),
        Stage(minLevel: 22, side: 3, faces: 5, colors: 6),
        Stage(minLevel: 32, side: 3, faces: 6, colors: 7),
        Stage(minLevel: 46, side: 4, faces: 4, colors: 7),
        Stage(minLevel: 60, side: 4, faces: 5, colors: 8),
        Stage(minLevel: 78, side: 4, faces: 6, colors: 9),
        Stage(minLevel: 105, side: 5, faces: 5, colors: 11),
        Stage(minLevel: 135, side: 5, faces: 6, colors: 12),
    ]

    private static let proStages = [
        Stage(minLevel: 1, side: 3, faces: 4, colors: 5),
        Stage(minLevel: 8, side: 3, faces: 6, colors: 7),
        Stage(minLevel: 20, side: 4, faces: 4, colors: 8),
        Stage(minLevel: 35, side: 4, faces: 6, colors: 10),
        Stage(minLevel: 60, side: 5, faces: 5, colors: 12),
        Stage(minLevel: 80, side: 5, faces: 6, colors: 14),
    ]

    public static func parameters(level: Int, track: LevelTrack) -> CubeLevelParameters {
        let level = max(1, level)
        let stages = track == .pro ? proStages : freeStages
        var stage = stages[0]
        for candidate in stages where level >= candidate.minLevel { stage = candidate }

        let boss = DifficultyCurve.isBoss(level: level)
        let breather = DifficultyCurve.isBreather(level: level)
        var faceCount = stage.faces
        var colors = stage.colors

        if boss {
            faceCount = min(6, faceCount + 1)
            colors += 1
        }
        if breather { colors = max(3, colors - 2) }

        let activeFaces = Array(CubeFace.allCases.prefix(faceCount))
        let cells = stage.side * stage.side * activeFaces.count
        var blockedPercent = track == .pro ? min(8, max(0, (level - 12) / 9)) : 0
        if breather { blockedPercent = 0 }
        let blocked = min(cells * blockedPercent / 100, max(0, cells / 8))
        let playable = cells - blocked
        colors = max(3, min(14, min(colors, max(3, playable / 2 - 1))))

        return CubeLevelParameters(
            side: stage.side,
            activeFaces: activeFaces,
            colors: colors,
            blocked: blocked,
            isBoss: boss,
            isBreather: breather
        )
    }

    public static func targetTwistiness(level: Int, track: LevelTrack) -> Double {
        let base = track == .free ? 0.16 : 0.28
        let cap = track == .free ? 0.48 : 0.58
        let growth = min(1.0, Double(max(0, level - 1)) / 85.0)
        return base + (cap - base) * growth
    }

    /// A cubical level must force the player around corners, not merely paste
    /// six unrelated flat boards onto a rotating model.
    public static func minimumSeamCrossings(parameters: CubeLevelParameters) -> Int {
        min(max(1, parameters.activeFaces.count - 1), max(1, parameters.colors / 2))
    }
}
