import Testing
@testable import PuzzleKit

struct LeaderboardTests {

    private func outcome(
        seconds: Int = 42,
        moves: Int = 6,
        hintsUsed: Int = 0
    ) -> LevelOutcome {
        LevelOutcome(
            level: 50, track: .free, moves: moves, par: 6, seconds: seconds,
            hintsUsed: hintsUsed, stars: 3, gems: 13, isFirstClear: true
        )
    }

    private func profile(freeCleared: Int = 0, proCleared: Int = 0, stars: Int = 0) -> PlayerProfile {
        var profile = PlayerProfile()
        for level in 0..<max(freeCleared, 0) {
            profile.free.register(LevelOutcome(
                level: level + 1, track: .free, moves: 3, par: 3, seconds: 10,
                hintsUsed: 0, stars: 0, gems: 0, isFirstClear: true
            ))
        }
        for level in 0..<max(proCleared, 0) {
            profile.pro.register(LevelOutcome(
                level: level + 1, track: .pro, moves: 5, par: 5, seconds: 10,
                hintsUsed: 0, stars: 0, gems: 0, isFirstClear: true
            ))
        }
        if stars > 0 {
            profile.free.records["1"] = LevelRecord(stars: stars, bestMoves: 3, bestSeconds: 10)
            profile.free.highestUnlocked = max(profile.free.highestUnlocked, 2)
        }
        return profile
    }

    @Test("identifiers are unique and namespaced under the bundle")
    func identifiersAreWellFormed() {
        let ids = LeaderboardID.allCases.map(\.rawValue)
        #expect(Set(ids).count == ids.count)
        for id in ids {
            #expect(id.hasPrefix("com.sabettaworks.LineFlowSW.leaderboard."))
        }
    }

    @Test("only the daily board is a timed, resetting race")
    func boardKindsAreDistinct() {
        for board in LeaderboardID.allCases {
            #expect(board.isRecurring == (board == .dailyTime))
            #expect(board.lowerIsBetter == (board == .dailyTime))
        }
        #expect(LeaderboardID.dailyTime.scoreFormat.contains("Time"))
        #expect(LeaderboardID.totalStars.scoreFormat == "Integer")
    }

    @Test("localisation keys are distinct per board")
    func localisationKeysAreDistinct() {
        let titles = LeaderboardID.allCases.map(\.titleKey)
        #expect(Set(titles).count == titles.count)
        let details = LeaderboardID.allCases.map(\.detailKey)
        #expect(Set(details).count == details.count)
    }

    @Test("a player who has done nothing is not put on any board")
    func emptyProfilePostsNothing() {
        #expect(LeaderboardRules.standings(for: PlayerProfile()).isEmpty)
    }

    @Test("standings post the star total and the furthest level of each track")
    func standingsCoverBothTracks() {
        let standings = LeaderboardRules.standings(for: profile(freeCleared: 12, proCleared: 4, stars: 3))
        let byBoard = Dictionary(uniqueKeysWithValues: standings.map { ($0.leaderboard, $0.score) })

        #expect(byBoard[.freeTrack] == 12)
        #expect(byBoard[.proTrack] == 4)
        #expect(byBoard[.totalStars] == 3)
    }

    @Test("a player who never touched the Pro track is left off that board")
    func proBoardIsSkippedWithoutProPlay() {
        let boards = LeaderboardRules.standings(for: profile(freeCleared: 5)).map(\.leaderboard)
        #expect(boards.contains(.freeTrack))
        #expect(!boards.contains(.proTrack))
    }

    @Test("the daily posts the time, and carries the move count alongside it")
    func dailyCarriesMovesAsContext() {
        let submission = LeaderboardRules.daily(for: outcome(seconds: 73, moves: 8))
        #expect(submission?.leaderboard == .dailyTime)
        #expect(submission?.score == 73)
        #expect(submission?.context == 8)
    }

    @Test("a hinted run is disqualified from the daily board")
    func hintsDisqualifyTheDaily() {
        #expect(LeaderboardRules.daily(for: outcome(hintsUsed: 1)) == nil)
        // ...but the run still counts toward the standings.
        let all = LeaderboardRules.afterDaily(
            outcome: outcome(hintsUsed: 1),
            profile: profile(freeCleared: 3, stars: 2)
        )
        #expect(!all.map(\.leaderboard).contains(.dailyTime))
        #expect(all.map(\.leaderboard).contains(.totalStars))
    }

    @Test("an impossibly fast run is not posted")
    func zeroTimeIsRejected() {
        #expect(LeaderboardRules.daily(for: outcome(seconds: 0)) == nil)
    }

    @Test("finishing a campaign level never posts to the daily board")
    func campaignDoesNotTouchTheDaily() {
        let boards = LeaderboardRules
            .afterCampaignLevel(profile: profile(freeCleared: 9, stars: 3))
            .map(\.leaderboard)
        #expect(!boards.contains(.dailyTime))
        #expect(boards.contains(.freeTrack))
    }

    @Test("standings can be reposted safely, which is what heals a failed send")
    func standingsAreIdempotent() {
        let player = profile(freeCleared: 7, proCleared: 2, stars: 3)
        #expect(LeaderboardRules.standings(for: player) == LeaderboardRules.standings(for: player))
    }
}
