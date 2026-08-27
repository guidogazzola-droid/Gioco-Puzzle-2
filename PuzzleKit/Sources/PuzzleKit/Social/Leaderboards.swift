import Foundation

/// The Game Center leaderboards the game posts to.
///
/// The identifiers must match the ones configured in App Store Connect
/// exactly. A mismatch fails silently at submission time - no crash, no
/// warning, the score simply never appears - which is the worst possible way
/// to find out. `tools/check_products.py` verifies they stay namespaced under
/// the bundle id, and `tools/check_localization.py` verifies every board has a
/// title and a description in both languages.
public enum LeaderboardID: String, CaseIterable, Sendable, Identifiable {

    /// All-time star total across both tracks. The headline board.
    case totalStars = "com.sabettalineflow.app.leaderboard.stars"
    /// Furthest level cleared on the free track.
    case freeTrack = "com.sabettalineflow.app.leaderboard.free"
    /// Furthest level cleared on the Pro track.
    case proTrack = "com.sabettalineflow.app.leaderboard.pro"
    /// Time on today's daily board. Everyone plays the identical puzzle, which
    /// is what makes this the only leaderboard here that is a fair race.
    case dailyTime = "com.sabettalineflow.app.leaderboard.daily"

    public var id: String { rawValue }

    public var titleKey: String { "leaderboard.\(shortKey).title" }
    public var detailKey: String { "leaderboard.\(shortKey).detail" }

    private var shortKey: String {
        switch self {
        case .totalStars: "stars"
        case .freeTrack: "free"
        case .proTrack: "pro"
        case .dailyTime: "daily"
        }
    }

    /// The daily board resets every 24 hours; the rest are all-time.
    /// Configure this as a recurring leaderboard in App Store Connect.
    public var isRecurring: Bool { self == .dailyTime }

    /// A time is better when it is smaller. Everything else is better bigger.
    /// This must match the sort order set in App Store Connect.
    public var lowerIsBetter: Bool { self == .dailyTime }

    /// What one unit of score means, for the App Store Connect format field.
    public var scoreFormat: String {
        switch self {
        case .totalStars, .freeTrack, .proTrack: "Integer"
        case .dailyTime: "Elapsed Time - Seconds"
        }
    }
}

/// One score, ready to post.
public struct LeaderboardSubmission: Hashable, Sendable {
    public let leaderboard: LeaderboardID
    public let score: Int
    /// Game Center's per-score context value. Used here to carry the move
    /// count alongside a daily time, so a board can show both.
    public let context: Int

    public init(leaderboard: LeaderboardID, score: Int, context: Int = 0) {
        self.leaderboard = leaderboard
        self.score = score
        self.context = context
    }
}

/// Decides what gets posted and when.
///
/// Kept out of the Game Center service on purpose: GameKit cannot be unit
/// tested, but *these* rules are exactly the part worth testing.
public enum LeaderboardRules {

    /// Standing totals. They are safe to post at any time and posting them
    /// repeatedly is harmless - Game Center keeps the best - which is what
    /// makes them self-healing after a submission failed offline.
    public static func standings(for profile: PlayerProfile) -> [LeaderboardSubmission] {
        var submissions: [LeaderboardSubmission] = []

        // A zero score would put a player who has done nothing on the board.
        if profile.totalStars > 0 {
            submissions.append(.init(leaderboard: .totalStars, score: profile.totalStars))
        }
        if profile.free.highestCleared > 0 {
            submissions.append(.init(leaderboard: .freeTrack, score: profile.free.highestCleared))
        }
        if profile.pro.highestCleared > 0 {
            submissions.append(.init(leaderboard: .proTrack, score: profile.pro.highestCleared))
        }
        return submissions
    }

    /// Today's daily time, or `nil` when the run does not qualify.
    ///
    /// A hint solves a whole colour outright, so a hinted run is not a race
    /// against the other players - it is disqualified rather than ranked, which
    /// is the only way the daily board means anything.
    public static func daily(for outcome: LevelOutcome) -> LeaderboardSubmission? {
        guard outcome.hintsUsed == 0, outcome.seconds > 0 else { return nil }
        return .init(leaderboard: .dailyTime, score: outcome.seconds, context: outcome.moves)
    }

    /// Everything to post after finishing a campaign level.
    public static func afterCampaignLevel(profile: PlayerProfile) -> [LeaderboardSubmission] {
        standings(for: profile)
    }

    /// Everything to post after finishing the daily board.
    public static func afterDaily(
        outcome: LevelOutcome,
        profile: PlayerProfile
    ) -> [LeaderboardSubmission] {
        standings(for: profile) + (daily(for: outcome).map { [$0] } ?? [])
    }
}
