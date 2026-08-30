import Testing
@testable import PuzzleKit

struct CubeLevelGeneratorTests {
    static let sweep = 1...160

    @Test("every cubical board is a valid surface covering", arguments: LevelTrack.allCases)
    func boardsAreValid(track: LevelTrack) {
        for level in Self.sweep {
            let board = CubeLevelGenerator.generate(level: level, track: track)
            let failure = CubeLevelValidator.validate(board)
            #expect(
                failure == nil,
                "level \(level) on \(track.rawValue): \(failure?.rawValue ?? "unknown")"
            )
            let parameters = CubeDifficultyCurve.parameters(level: level, track: track)
            #expect(board.side == parameters.side)
            #expect(board.activeFaces == parameters.activeFaces)
            #expect(board.colorCount == parameters.colors)
            #expect(board.seamCrossings >= CubeDifficultyCurve.minimumSeamCrossings(parameters: parameters))
        }
    }

    @Test("cubical generation is deterministic", arguments: LevelTrack.allCases)
    func deterministic(track: LevelTrack) {
        for level in [1, 8, 22, 47, 80, 135, 200] {
            let first = CubeLevelGenerator.generate(level: level, track: track)
            let second = CubeLevelGenerator.generate(level: level, track: track)
            #expect(first == second)
        }
    }

    @Test("the campaign unfolds from a corner to all six faces")
    func faceProgression() {
        #expect(CubeDifficultyCurve.parameters(level: 1, track: .free).activeFaces.count == 2)
        #expect(CubeDifficultyCurve.parameters(level: 12, track: .free).activeFaces.count >= 4)
        #expect(CubeDifficultyCurve.parameters(level: 40, track: .free).activeFaces.count == 6)
        #expect(CubeDifficultyCurve.parameters(level: 90, track: .pro).activeFaces.count == 6)
    }

    @Test("fallbacks are valid and retain every forced seam")
    func fallbackIsValid() {
        for level in [1, 12, 40, 80, 140] {
            for track in LevelTrack.allCases {
                let parameters = CubeDifficultyCurve.parameters(level: level, track: track)
                let board = CubeLevelGenerator.fallback(
                    level: level, track: track, parameters: parameters
                )
                #expect(CubeLevelValidator.validate(board) == nil)
                #expect(board.colorCount == parameters.colors)
                #expect(board.seamCrossings >= parameters.activeFaces.count - 1)
            }
        }
    }

    @Test("daily cubes stay stable for a calendar key")
    func dailyIsStable() {
        let first = DailyChallenge.cubeBlueprint(forDay: "2026-08-30")
        let second = DailyChallenge.cubeBlueprint(forDay: "2026-08-30")
        let next = DailyChallenge.cubeBlueprint(forDay: "2026-08-31")
        #expect(first == second)
        #expect(first.seed != next.seed || first.solution != next.solution)
    }
}
