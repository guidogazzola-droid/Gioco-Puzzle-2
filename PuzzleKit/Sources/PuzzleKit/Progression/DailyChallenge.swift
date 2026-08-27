import Foundation

/// One extra board per calendar day, identical for every player.
///
/// The daily board is the cheapest retention hook a puzzle game has: it costs
/// no content budget because it is generated, and it gives a reason to open the
/// app on a day the player has no campaign appetite.
public enum DailyChallenge {

    /// Difficulty band the daily draws from - hard enough to matter, reachable
    /// for a player who has only cleared the first chapter.
    static let band: ClosedRange<Int> = 35...70

    public static func salt(forDay day: String) -> UInt64 {
        SeededRandom.hash("lineflow.daily.\(day)")
    }

    public static func level(forDay day: String) -> Int {
        var rng = SeededRandom(seed: salt(forDay: day))
        return band.lowerBound + rng.int(below: band.count)
    }

    public static func blueprint(forDay day: String) -> LevelBlueprint {
        LevelGenerator.generate(level: level(forDay: day), track: .free, salt: salt(forDay: day))
    }

    public static func blueprint(for date: Date, calendar: Calendar = .current) -> LevelBlueprint {
        blueprint(forDay: DayKey.key(for: date, calendar: calendar))
    }

    /// Bonus gems on top of the normal level award, so the daily is worth the
    /// detour even once the player has cleared that difficulty band.
    public static func bonusGems(stars: Int, streak: Int) -> Int {
        let streakBonus = min(25, streak * 2)
        return 10 + stars * 5 + streakBonus
    }
}
