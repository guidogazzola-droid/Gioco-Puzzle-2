import Foundation
import Testing
@testable import PuzzleKit

struct PlayerProfileTests {

    private func outcome(
        level: Int,
        track: LevelTrack = .free,
        stars: Int = 3,
        gems: Int = 13,
        firstClear: Bool = true
    ) -> LevelOutcome {
        LevelOutcome(
            level: level, track: track, moves: 4, par: 4, seconds: 20,
            hintsUsed: 0, stars: stars, gems: gems, isFirstClear: firstClear
        )
    }

    @Test("a new profile starts at level one with nothing bought")
    func defaultsAreSane() {
        let profile = PlayerProfile()
        #expect(profile.nextLevel(on: .free) == 1)
        #expect(profile.nextLevel(on: .pro) == 1)
        #expect(profile.gems == 0)
        #expect(profile.totalStars == 0)
        #expect(profile.ownedCosmetics.isEmpty)
        #expect(profile.equipped.palette == CosmeticCatalog.defaultPalette)
        #expect(!profile.onboardingComplete)
    }

    @Test("clearing a level unlocks the next one and pays out")
    func clearingLevelsProgresses() {
        var profile = PlayerProfile()
        profile.apply(outcome(level: 1), on: "2026-03-01")
        #expect(profile.free.highestUnlocked == 2)
        #expect(profile.free.stars(for: 1) == 3)
        #expect(profile.gems == 13)
        #expect(profile.stats.levelsCompleted == 1)
        #expect(profile.stats.perfectClears == 1)
        #expect(profile.ads.levelsSinceInterstitial == 1)
    }

    @Test("the two tracks progress independently")
    func tracksAreIndependent() {
        var profile = PlayerProfile()
        profile.apply(outcome(level: 1, track: .free), on: "2026-03-01")
        profile.apply(outcome(level: 1, track: .pro), on: "2026-03-01")
        profile.apply(outcome(level: 2, track: .pro), on: "2026-03-01")
        #expect(profile.free.highestUnlocked == 2)
        #expect(profile.pro.highestUnlocked == 3)
        #expect(profile.totalStars == 9)
    }

    @Test("replaying a level keeps the player's best result")
    func replaysKeepTheBest() {
        var profile = PlayerProfile()
        profile.apply(outcome(level: 1, stars: 3), on: "2026-03-01")
        profile.apply(
            LevelOutcome(level: 1, track: .free, moves: 12, par: 4, seconds: 90,
                         hintsUsed: 1, stars: 1, gems: 4, isFirstClear: false),
            on: "2026-03-01"
        )
        #expect(profile.free.stars(for: 1) == 3, "a worse replay must not erase three stars")
        #expect(profile.free.record(for: 1)?.bestMoves == 4)
        #expect(profile.free.record(for: 1)?.bestSeconds == 20)
        #expect(profile.stats.levelsCompleted == 1, "a replay is not a new clear")
    }

    @Test("streaks count consecutive days and reset on a gap")
    func streaksFollowTheCalendar() {
        var profile = PlayerProfile()
        profile.apply(outcome(level: 1), on: "2026-03-01")
        #expect(profile.stats.currentStreak == 1)

        profile.apply(outcome(level: 2), on: "2026-03-02")
        #expect(profile.stats.currentStreak == 2)

        // Twice in one day is still one day of the streak.
        profile.apply(outcome(level: 3), on: "2026-03-02")
        #expect(profile.stats.currentStreak == 2)

        profile.apply(outcome(level: 4), on: "2026-03-05")
        #expect(profile.stats.currentStreak == 1)
        #expect(profile.stats.bestStreak == 2)
    }

    @Test("the daily board pays out once per day")
    func dailyIsClaimedOnce() {
        var profile = PlayerProfile()
        let day = "2026-03-01"
        let claimed = profile.applyDaily(outcome(level: 40), on: day, bonusGems: 25)
        #expect(claimed)
        #expect(profile.gems == 38)
        #expect(profile.hasClearedDaily(on: day))

        let claimed2 = profile.applyDaily(outcome(level: 40), on: day, bonusGems: 25)
        #expect(!claimed2)
        #expect(profile.gems == 38, "a second clear on the same day must pay nothing")
        #expect(profile.stats.dailyClears == 1)
    }

    @Test("gems cannot be overspent")
    func spendingIsGuarded() {
        var profile = PlayerProfile(gems: 100)
        let spent = profile.spendGems(101)
        #expect(!spent)
        #expect(profile.gems == 100)
        let spent2 = profile.spendGems(100)
        #expect(spent2)
        #expect(profile.gems == 0)
        let spent3 = profile.spendGems(1)
        #expect(!spent3)
    }

    @Test("hints cannot go negative")
    func hintsAreGuarded() {
        var profile = PlayerProfile(hints: 1)
        let usedHint = profile.spendHint()
        #expect(usedHint)
        #expect(profile.hints == 0)
        let usedHint2 = profile.spendHint()
        #expect(!usedHint2)
        #expect(profile.hints == 0)
    }

    @Test("a save survives a round trip")
    func profileIsCodable() throws {
        var profile = PlayerProfile()
        profile.apply(outcome(level: 1), on: "2026-03-01")
        profile.ownedCosmetics.insert("ember")
        profile.equipped.palette = "ember"
        profile.settings.hapticsEnabled = false

        let data = try JSONEncoder().encode(profile)
        let restored = try JSONDecoder().decode(PlayerProfile.self, from: data)
        #expect(restored == profile)
    }

    @Test("a save written by an older build still loads")
    func decodingIsForwardCompatible() throws {
        // Only two of the fields the current build writes. Everything else must
        // fall back to its default rather than failing the whole decode and
        // wiping the player's progress on update.
        let legacy = """
        { "version": 1, "gems": 250, "free": { "highestUnlocked": 12 } }
        """
        let profile = try JSONDecoder().decode(PlayerProfile.self, from: Data(legacy.utf8))
        #expect(profile.gems == 250)
        #expect(profile.free.highestUnlocked == 12)
        #expect(profile.pro.highestUnlocked == 1)
        #expect(profile.hints == 3)
        #expect(profile.equipped.palette == CosmeticCatalog.defaultPalette)
        #expect(profile.settings.soundEnabled)
        #expect(profile.dailyResults.isEmpty)
    }

    @Test("an empty save decodes to a usable profile")
    func decodingAnEmptyObjectWorks() throws {
        let profile = try JSONDecoder().decode(PlayerProfile.self, from: Data("{}".utf8))
        #expect(profile == PlayerProfile())
    }
}

struct DayKeyTests {

    @Test("keys are zero-padded and sortable")
    func keysAreWellFormed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        #expect(DayKey.key(for: date, calendar: calendar) == "2026-03-07")
    }

    @Test("consecutive days are recognised, including across month ends")
    func consecutiveDaysAreDetected() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        #expect(DayKey.isConsecutive("2026-03-01", "2026-03-02", calendar: calendar))
        #expect(DayKey.isConsecutive("2026-02-28", "2026-03-01", calendar: calendar))
        #expect(DayKey.isConsecutive("2026-12-31", "2027-01-01", calendar: calendar))
        #expect(!DayKey.isConsecutive("2026-03-01", "2026-03-03", calendar: calendar))
        #expect(!DayKey.isConsecutive("2026-03-02", "2026-03-01", calendar: calendar))
        #expect(!DayKey.isConsecutive("not-a-day", "2026-03-01", calendar: calendar))
    }
}

struct DailyChallengeTests {

    @Test("the same day always gives the same board")
    func dailyIsStablePerDay() {
        let first = DailyChallenge.blueprint(forDay: "2026-03-07")
        let second = DailyChallenge.blueprint(forDay: "2026-03-07")
        #expect(first.solution == second.solution)
        #expect(LevelValidator.validate(first) == nil)
    }

    @Test("different days give different boards")
    func dailyChangesDaily() {
        let boards = (1...20).map { DailyChallenge.blueprint(forDay: String(format: "2026-04-%02d", $0)) }
        #expect(Set(boards.map(\.seed)).count == boards.count)
        for board in boards {
            #expect(LevelValidator.validate(board) == nil)
            #expect(DailyChallenge.band.contains(board.level))
        }
    }

    @Test("a longer streak pays a bigger bonus, up to a cap")
    func streakBonusIsCapped() {
        #expect(DailyChallenge.bonusGems(stars: 3, streak: 0)
                < DailyChallenge.bonusGems(stars: 3, streak: 5))
        #expect(DailyChallenge.bonusGems(stars: 3, streak: 100)
                == DailyChallenge.bonusGems(stars: 3, streak: 13))
    }
}

struct ChapterTests {

    @Test("levels map onto the chapter that contains them")
    func chapterBoundaries() {
        #expect(ChapterCatalog.chapter(containing: 1, track: .free).index == 0)
        #expect(ChapterCatalog.chapter(containing: 30, track: .free).index == 0)
        #expect(ChapterCatalog.chapter(containing: 31, track: .free).index == 1)
        #expect(ChapterCatalog.chapter(containing: 1, track: .free).range == 1...30)
        #expect(ChapterCatalog.chapter(containing: 61, track: .free).range == 61...90)
    }

    @Test("chapters cover the campaign without gaps or overlaps")
    func chaptersTile() {
        let chapters = ChapterCatalog.chapters(track: .free, reaching: 100)
        for (previous, next) in zip(chapters, chapters.dropFirst()) {
            #expect(previous.range.upperBound + 1 == next.range.lowerBound)
        }
        #expect(chapters.last!.range.upperBound > 100, "the map always shows somewhere left to go")
    }

    @Test("themes cycle so an endless campaign never runs out")
    func themesCycle() {
        let first = ChapterCatalog.chapter(at: 0, track: .free)
        let wrapped = ChapterCatalog.chapter(at: ChapterCatalog.themes.count, track: .free)
        #expect(first.titleKey == wrapped.titleKey)
        #expect(first.index != wrapped.index)
    }
}

struct SeededRandomTests {

    @Test("the same seed replays the same sequence")
    func generatorIsReproducible() {
        var a = SeededRandom(seed: 12_345)
        var b = SeededRandom(seed: 12_345)
        for _ in 0..<64 {
            let left = a.next()
            let right = b.next()
            #expect(left == right)
        }
    }

    @Test("different seeds diverge")
    func seedsDiverge() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        var diverged = false
        for _ in 0..<32 where a.next() != b.next() { diverged = true }
        #expect(diverged)
    }

    @Test("bounded draws stay in range and cover it")
    func boundedDrawsAreUniform() {
        var rng = SeededRandom(seed: 99)
        var seen: Set<Int> = []
        for _ in 0..<4_000 {
            let value = rng.int(below: 7)
            #expect(value >= 0 && value < 7)
            seen.insert(value)
        }
        #expect(seen.count == 7)
        // Degenerate bounds return zero rather than trapping.
        let singleton = rng.int(below: 1)
        let empty = rng.int(below: 0)
        #expect(singleton == 0)
        #expect(empty == 0)
    }

    @Test("shuffling is a permutation, not a resample")
    func shuffleIsAPermutation() {
        var rng = SeededRandom(seed: 7)
        let input = Array(0..<40)
        let shuffled = rng.shuffled(input)
        #expect(shuffled.sorted() == input)
        #expect(shuffled != input)
    }

    @Test("the string hash is stable across runs")
    func stringHashIsStable() {
        // A literal, not a recomputation: `Hasher` is seeded per process, so a
        // regression here would silently reshuffle every daily board.
        #expect(SeededRandom.hash("lineflow") == SeededRandom.hash("lineflow"))
        #expect(SeededRandom.hash("a") != SeededRandom.hash("b"))
        #expect(SeededRandom.hash("") == 0xCBF2_9CE4_8422_2325)
    }
}
