import Foundation

/// Best result recorded for one level.
public struct LevelRecord: Codable, Sendable, Hashable {
    public var stars: Int
    public var bestMoves: Int
    public var bestSeconds: Int

    public init(stars: Int = 0, bestMoves: Int = .max, bestSeconds: Int = .max) {
        self.stars = stars
        self.bestMoves = bestMoves
        self.bestSeconds = bestSeconds
    }
}

/// Progress along one of the two tracks.
public struct TrackProgress: Codable, Sendable, Hashable {

    public var highestUnlocked: Int
    /// Keyed by `String(level)` so the save file stays human-readable.
    public var records: [String: LevelRecord]

    public init(highestUnlocked: Int = 1, records: [String: LevelRecord] = [:]) {
        self.highestUnlocked = highestUnlocked
        self.records = records
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        highestUnlocked = try container.decodeIfPresent(Int.self, forKey: .highestUnlocked) ?? 1
        records = try container.decodeIfPresent([String: LevelRecord].self, forKey: .records) ?? [:]
    }

    public func record(for level: Int) -> LevelRecord? { records[String(level)] }

    public func stars(for level: Int) -> Int { records[String(level)]?.stars ?? 0 }

    public func isCleared(_ level: Int) -> Bool { records[String(level)] != nil }

    public func isUnlocked(_ level: Int) -> Bool { level <= highestUnlocked }

    public var totalStars: Int { records.values.reduce(0) { $0 + $1.stars } }

    public var clearedLevels: Int { records.count }

    /// The furthest level ever finished. `highestUnlocked` runs one ahead of
    /// it, because clearing a level unlocks the next one.
    public var highestCleared: Int { max(0, highestUnlocked - 1) }

    /// Records a clear, keeping the player's best result for that level.
    public mutating func register(_ outcome: LevelOutcome) {
        let key = String(outcome.level)
        var record = records[key] ?? LevelRecord()
        record.stars = max(record.stars, outcome.stars)
        record.bestMoves = min(record.bestMoves, outcome.moves)
        record.bestSeconds = min(record.bestSeconds, outcome.seconds)
        records[key] = record
        highestUnlocked = max(highestUnlocked, outcome.level + 1)
    }
}

/// What the player currently has equipped, by cosmetic id.
public struct EquippedCosmetics: Codable, Sendable, Hashable {
    public var palette: String
    public var trail: String
    public var background: String
    public var nodeShape: String

    public init(
        palette: String = CosmeticCatalog.defaultPalette,
        trail: String = CosmeticCatalog.defaultTrail,
        background: String = CosmeticCatalog.defaultBackground,
        nodeShape: String = CosmeticCatalog.defaultNodeShape
    ) {
        self.palette = palette
        self.trail = trail
        self.background = background
        self.nodeShape = nodeShape
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        palette = try container.decodeIfPresent(String.self, forKey: .palette) ?? CosmeticCatalog.defaultPalette
        trail = try container.decodeIfPresent(String.self, forKey: .trail) ?? CosmeticCatalog.defaultTrail
        background = try container.decodeIfPresent(String.self, forKey: .background) ?? CosmeticCatalog.defaultBackground
        nodeShape = try container.decodeIfPresent(String.self, forKey: .nodeShape) ?? CosmeticCatalog.defaultNodeShape
    }

    public func id(for category: Cosmetic.Category) -> String {
        switch category {
        case .palette: palette
        case .trail: trail
        case .background: background
        case .nodeShape: nodeShape
        }
    }

    public mutating func set(_ id: String, for category: Cosmetic.Category) {
        switch category {
        case .palette: palette = id
        case .trail: trail = id
        case .background: background = id
        case .nodeShape: nodeShape = id
        }
    }
}

public struct GameSettings: Codable, Sendable, Hashable {
    public var soundEnabled: Bool
    public var musicEnabled: Bool
    public var hapticsEnabled: Bool
    /// Draws a distinct glyph on each endpoint pair as well as colouring it.
    public var colorBlindAssist: Bool
    public var reduceMotion: Bool

    public init(
        soundEnabled: Bool = true,
        musicEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        colorBlindAssist: Bool = false,
        reduceMotion: Bool = false
    ) {
        self.soundEnabled = soundEnabled
        self.musicEnabled = musicEnabled
        self.hapticsEnabled = hapticsEnabled
        self.colorBlindAssist = colorBlindAssist
        self.reduceMotion = reduceMotion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        musicEnabled = try container.decodeIfPresent(Bool.self, forKey: .musicEnabled) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        colorBlindAssist = try container.decodeIfPresent(Bool.self, forKey: .colorBlindAssist) ?? false
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
    }
}

public struct PlayerStats: Codable, Sendable, Hashable {
    public var levelsCompleted: Int
    public var perfectClears: Int
    public var currentStreak: Int
    public var bestStreak: Int
    public var dailyClears: Int
    public var lastPlayedDay: String?

    public init(
        levelsCompleted: Int = 0,
        perfectClears: Int = 0,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        dailyClears: Int = 0,
        lastPlayedDay: String? = nil
    ) {
        self.levelsCompleted = levelsCompleted
        self.perfectClears = perfectClears
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.dailyClears = dailyClears
        self.lastPlayedDay = lastPlayedDay
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        levelsCompleted = try container.decodeIfPresent(Int.self, forKey: .levelsCompleted) ?? 0
        perfectClears = try container.decodeIfPresent(Int.self, forKey: .perfectClears) ?? 0
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        bestStreak = try container.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        dailyClears = try container.decodeIfPresent(Int.self, forKey: .dailyClears) ?? 0
        lastPlayedDay = try container.decodeIfPresent(String.self, forKey: .lastPlayedDay)
    }

    /// Advances the play streak for `day`, which must be a `DayKey` string.
    public mutating func registerPlay(on day: String, calendar: Calendar = .current) {
        defer { lastPlayedDay = day }
        guard let previous = lastPlayedDay else {
            currentStreak = 1
            bestStreak = max(bestStreak, 1)
            return
        }
        if previous == day { return }
        currentStreak = DayKey.isConsecutive(previous, day, calendar: calendar) ? currentStreak + 1 : 1
        bestStreak = max(bestStreak, currentStreak)
    }
}

/// Ad pacing counters that must survive an app relaunch.
public struct AdState: Codable, Sendable, Hashable {
    public var levelsSinceInterstitial: Int
    public var lastInterstitialAt: Date?

    public init(levelsSinceInterstitial: Int = 0, lastInterstitialAt: Date? = nil) {
        self.levelsSinceInterstitial = levelsSinceInterstitial
        self.lastInterstitialAt = lastInterstitialAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        levelsSinceInterstitial = try container.decodeIfPresent(Int.self, forKey: .levelsSinceInterstitial) ?? 0
        lastInterstitialAt = try container.decodeIfPresent(Date.self, forKey: .lastInterstitialAt)
    }
}

/// The complete local save.
///
/// Decoding is field-by-field with defaults rather than the synthesised
/// initialiser: a save written by an older build must never fail to load, and
/// wiping progress on update is how a puzzle game earns one-star reviews.
public struct PlayerProfile: Codable, Sendable, Hashable {

    public static let currentVersion = 1

    /// How many days of daily results to keep.
    ///
    /// The game only ever asks whether *today* has been claimed, so the stored
    /// outcomes are history rather than state. Keeping them all made them ~80%
    /// of the save file and would have pushed it past iCloud's 1 MB key-value
    /// ceiling after about twenty years of play. Sixty days is plenty for a
    /// history screen and keeps the file flat forever.
    public static let dailyHistoryLimit = 60

    public var version: Int
    public var free: TrackProgress
    public var pro: TrackProgress
    public var gems: Int
    public var hints: Int
    /// Cosmetics owned outright - these survive a lapsed subscription.
    public var ownedCosmetics: Set<String>
    public var equipped: EquippedCosmetics
    public var stats: PlayerStats
    public var settings: GameSettings
    public var ads: AdState
    public var dailyResults: [String: LevelOutcome]
    public var onboardingComplete: Bool

    public init(
        version: Int = PlayerProfile.currentVersion,
        free: TrackProgress = TrackProgress(),
        pro: TrackProgress = TrackProgress(),
        gems: Int = 0,
        hints: Int = 3,
        ownedCosmetics: Set<String> = [],
        equipped: EquippedCosmetics = EquippedCosmetics(),
        stats: PlayerStats = PlayerStats(),
        settings: GameSettings = GameSettings(),
        ads: AdState = AdState(),
        dailyResults: [String: LevelOutcome] = [:],
        onboardingComplete: Bool = false
    ) {
        self.version = version
        self.free = free
        self.pro = pro
        self.gems = gems
        self.hints = hints
        self.ownedCosmetics = ownedCosmetics
        self.equipped = equipped
        self.stats = stats
        self.settings = settings
        self.ads = ads
        self.dailyResults = dailyResults
        self.onboardingComplete = onboardingComplete
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? PlayerProfile.currentVersion
        free = try container.decodeIfPresent(TrackProgress.self, forKey: .free) ?? TrackProgress()
        pro = try container.decodeIfPresent(TrackProgress.self, forKey: .pro) ?? TrackProgress()
        gems = try container.decodeIfPresent(Int.self, forKey: .gems) ?? 0
        hints = try container.decodeIfPresent(Int.self, forKey: .hints) ?? 3
        ownedCosmetics = try container.decodeIfPresent(Set<String>.self, forKey: .ownedCosmetics) ?? []
        equipped = try container.decodeIfPresent(EquippedCosmetics.self, forKey: .equipped) ?? EquippedCosmetics()
        stats = try container.decodeIfPresent(PlayerStats.self, forKey: .stats) ?? PlayerStats()
        settings = try container.decodeIfPresent(GameSettings.self, forKey: .settings) ?? GameSettings()
        ads = try container.decodeIfPresent(AdState.self, forKey: .ads) ?? AdState()
        dailyResults = try container.decodeIfPresent([String: LevelOutcome].self, forKey: .dailyResults) ?? [:]
        onboardingComplete = try container.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? false
        // Prune on load as well as on write, so a save written by a build that
        // kept everything shrinks the first time it is opened.
        pruneDailyResults()
    }

    // MARK: - Track access

    public func progress(for track: LevelTrack) -> TrackProgress {
        track == .free ? free : pro
    }

    public mutating func setProgress(_ progress: TrackProgress, for track: LevelTrack) {
        if track == .free { free = progress } else { pro = progress }
    }

    public var totalStars: Int { free.totalStars + pro.totalStars }

    /// The next level the player should be dropped into on "Play".
    public func nextLevel(on track: LevelTrack) -> Int {
        max(1, progress(for: track).highestUnlocked)
    }

    // MARK: - Mutations

    /// Books a finished campaign level: records, currency, stats and ad pacing.
    public mutating func apply(
        _ outcome: LevelOutcome,
        on day: String,
        calendar: Calendar = .current
    ) {
        var track = progress(for: outcome.track)
        track.register(outcome)
        setProgress(track, for: outcome.track)

        gems += outcome.gems
        if outcome.isFirstClear { stats.levelsCompleted += 1 }
        if outcome.isPerfect { stats.perfectClears += 1 }
        stats.registerPlay(on: day, calendar: calendar)
        ads.levelsSinceInterstitial += 1
    }

    /// Books the daily board. Only the first clear of a given day counts.
    @discardableResult
    public mutating func applyDaily(
        _ outcome: LevelOutcome,
        on day: String,
        bonusGems: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard dailyResults[day] == nil else { return false }
        dailyResults[day] = outcome
        pruneDailyResults()
        gems += outcome.gems + bonusGems
        stats.dailyClears += 1
        stats.registerPlay(on: day, calendar: calendar)
        ads.levelsSinceInterstitial += 1
        return true
    }

    public func hasClearedDaily(on day: String) -> Bool { dailyResults[day] != nil }

    /// Drops all but the most recent `dailyHistoryLimit` days.
    ///
    /// Day keys are `yyyy-MM-dd`, so sorting them as strings is already
    /// chronological. Only today is ever queried, so dropping older days
    /// cannot make a claimed day look unclaimed in practice.
    mutating func pruneDailyResults() {
        guard dailyResults.count > Self.dailyHistoryLimit else { return }
        let keep = Set(dailyResults.keys.sorted().suffix(Self.dailyHistoryLimit))
        dailyResults = dailyResults.filter { keep.contains($0.key) }
    }

    @discardableResult
    public mutating func spendGems(_ amount: Int) -> Bool {
        guard amount >= 0, gems >= amount else { return false }
        gems -= amount
        return true
    }

    @discardableResult
    public mutating func spendHint() -> Bool {
        guard hints > 0 else { return false }
        hints -= 1
        return true
    }
}
