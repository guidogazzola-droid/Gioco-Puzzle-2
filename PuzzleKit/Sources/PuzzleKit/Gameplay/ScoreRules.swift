import Foundation

/// What the player walked away with after finishing a board.
public struct LevelOutcome: Codable, Sendable, Hashable {
    public let level: Int
    public let track: LevelTrack
    public let moves: Int
    public let par: Int
    public let seconds: Int
    public let hintsUsed: Int
    public let stars: Int
    public let gems: Int
    public let isFirstClear: Bool

    public var isPerfect: Bool { stars == 3 }
}

/// Star and reward rules.
///
/// Star thresholds are relative to par (one drag per colour) rather than
/// absolute, so they hold for every procedurally generated board without
/// per-level tuning - which is the whole point of not shipping level files.
public enum ScoreRules {

    /// Extra drags allowed while still earning two stars.
    public static func twoStarBudget(par: Int) -> Int { max(2, par / 2) }

    public static func stars(moves: Int, par: Int, hintsUsed: Int) -> Int {
        // A hint hands the player a whole colour, so it caps the award at two.
        if hintsUsed > 0 {
            return moves <= par + twoStarBudget(par) + hintsUsed ? 2 : 1
        }
        if moves <= par { return 3 }
        if moves <= par + twoStarBudget(par) { return 2 }
        return 1
    }

    /// Soft-currency award. Replays pay less so the campaign cannot be farmed,
    /// and Pro subscribers earn at `multiplier` - one of the things the
    /// subscription actually sells.
    public static func gems(
        stars: Int,
        parameters: LevelParameters,
        isFirstClear: Bool,
        multiplier: Int = 1
    ) -> Int {
        var total = 4 + stars * 3
        if parameters.isBoss { total += 10 }
        if !isFirstClear { total = max(1, total / 3) }
        return max(1, total * max(1, multiplier))
    }

    public static func outcome(
        level: Int,
        track: LevelTrack,
        parameters: LevelParameters,
        moves: Int,
        par: Int,
        seconds: Int,
        hintsUsed: Int,
        isFirstClear: Bool,
        gemMultiplier: Int
    ) -> LevelOutcome {
        let awarded = stars(moves: moves, par: par, hintsUsed: hintsUsed)
        return LevelOutcome(
            level: level,
            track: track,
            moves: moves,
            par: par,
            seconds: seconds,
            hintsUsed: hintsUsed,
            stars: awarded,
            gems: gems(
                stars: awarded,
                parameters: parameters,
                isFirstClear: isFirstClear,
                multiplier: gemMultiplier
            ),
            isFirstClear: isFirstClear
        )
    }
}
