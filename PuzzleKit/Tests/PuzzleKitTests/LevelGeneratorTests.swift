import Testing
@testable import PuzzleKit

/// The generator is the part of the game that cannot be hand-checked: it
/// produces boards nobody has ever seen. These tests are what stand in for a
/// level designer's eyes.
struct LevelGeneratorTests {

    /// Levels swept in the exhaustive checks. Deep enough to cover every stage
    /// of both difficulty curves, including the plateau past the last stage.
    static let sweep = 1...200

    @Test("every generated board is solvable by construction", arguments: LevelTrack.allCases)
    func boardsAreValid(track: LevelTrack) {
        for level in Self.sweep {
            let blueprint = LevelGenerator.generate(level: level, track: track)
            #expect(
                LevelValidator.validate(blueprint) == nil,
                "level \(level) on \(track.rawValue): \(LevelValidator.validate(blueprint)?.rawValue ?? "")"
            )
        }
    }

    @Test("the same level always generates the same board", arguments: LevelTrack.allCases)
    func generationIsDeterministic(track: LevelTrack) {
        for level in [1, 7, 10, 23, 42, 137, 200] {
            let first = LevelGenerator.generate(level: level, track: track)
            let second = LevelGenerator.generate(level: level, track: track)
            #expect(first.solution == second.solution)
            #expect(first.blocked == second.blocked)
            #expect(first.seed == second.seed)
            #expect(first.fluxRotors == second.fluxRotors)
        }
    }

    @Test("the two tracks never share a board")
    func tracksDiverge() {
        for level in [1, 5, 20, 60] {
            let free = LevelGenerator.generate(level: level, track: .free)
            let pro = LevelGenerator.generate(level: level, track: .pro)
            #expect(free.seed != pro.seed)
        }
    }

    @Test("colour count matches the difficulty curve", arguments: LevelTrack.allCases)
    func colorCountMatchesCurve(track: LevelTrack) {
        for level in Self.sweep {
            let expected = DifficultyCurve.parameters(level: level, track: track)
            let blueprint = LevelGenerator.generate(level: level, track: track)
            #expect(blueprint.colorCount == expected.colors, "level \(level) on \(track.rawValue)")
            #expect(blueprint.width == expected.width)
            #expect(blueprint.height == expected.height)
            #expect(blueprint.blocked.count == expected.blocked)
        }
    }

    @Test("no colour swallows the board", arguments: LevelTrack.allCases)
    func colorLengthsStayBalanced(track: LevelTrack) {
        for level in Self.sweep {
            let blueprint = LevelGenerator.generate(level: level, track: track)
            let lengths = blueprint.solution.map(\.count)
            let average = Double(blueprint.playableCells) / Double(blueprint.colorCount)
            let ratio = Double(lengths.max() ?? 0) / average
            // A single colour covering more than ~2.5x its share makes a board
            // unreadable; the generator's rebalance pass exists to prevent it.
            #expect(ratio < 2.5, "level \(level) on \(track.rawValue) ratio \(ratio)")
            #expect(lengths.min() ?? 0 >= 2)
        }
    }

    @Test("walls are a Pro-track feature only")
    func freeTrackHasNoWalls() {
        for level in Self.sweep {
            #expect(LevelGenerator.generate(level: level, track: .free).blocked.isEmpty)
        }
        let lateProLevels = (60...120).map { LevelGenerator.generate(level: $0, track: .pro) }
        let someHaveWalls = lateProLevels.contains { !$0.blocked.isEmpty }
        #expect(someHaveWalls)
    }

    @Test("walls never strand part of the board")
    func wallsKeepTheBoardConnected() {
        for level in 20...120 {
            let blueprint = LevelGenerator.generate(level: level, track: .pro)
            var free: Set<Coordinate> = []
            for y in 0..<blueprint.height {
                for x in 0..<blueprint.width where !blueprint.isBlocked(Coordinate(x, y)) {
                    free.insert(Coordinate(x, y))
                }
            }
            #expect(LevelGenerator.isConnected(free, width: blueprint.width, height: blueprint.height))
        }
    }

    @Test("endpoints are distinct and sit on playable cells")
    func endpointsAreWellFormed() {
        for level in Self.sweep {
            let blueprint = LevelGenerator.generate(level: level, track: .free)
            var seen: Set<Coordinate> = []
            for endpoints in blueprint.endpoints {
                #expect(endpoints.start != endpoints.end)
                #expect(blueprint.isPlayable(endpoints.start))
                #expect(blueprint.isPlayable(endpoints.end))
                #expect(seen.insert(endpoints.start).inserted)
                #expect(seen.insert(endpoints.end).inserted)
            }
        }
    }

    @Test("magnetic rotors are internal, owned and initially misaligned")
    func fluxRotorsAreWellFormed() {
        for level in Self.sweep {
            let blueprint = LevelGenerator.generate(level: level, track: .free)
            #expect(!blueprint.fluxRotors.isEmpty)
            #expect(blueprint.fluxRotors.count <= 5)

            var seen: Set<Coordinate> = []
            for rotor in blueprint.fluxRotors {
                #expect(seen.insert(rotor.coordinate).inserted)
                #expect(rotor.initial != rotor.target)
                #expect(blueprint.solution[rotor.color].dropFirst().dropLast().contains(rotor.coordinate))
                #expect(rotor.initial.cycleLength == rotor.target.cycleLength)
            }
        }
    }

    @Test("early levels stay readable and late levels get knotted")
    func twistinessFollowsTheCurve() {
        func density(_ level: Int) -> Double {
            let blueprint = LevelGenerator.generate(level: level, track: .free)
            return Double(blueprint.turnCount) / Double(blueprint.playableCells)
        }
        let early = (1...6).map(density).reduce(0, +) / 6
        let late = (120...140).map(density).reduce(0, +) / 21
        #expect(early < late)
        #expect(early < 0.40)
    }

    @Test("a salt produces a different board for the same level")
    func saltChangesTheBoard() {
        let plain = LevelGenerator.generate(level: 50, track: .free)
        let salted = LevelGenerator.generate(level: 50, track: .free, salt: 991)
        #expect(plain.solution != salted.solution)
        #expect(LevelValidator.validate(salted) == nil)
    }

    @Test("the fallback board is itself a valid covering")
    func fallbackIsValid() {
        for level in [1, 10, 55, 130] {
            for track in LevelTrack.allCases {
                let parameters = DifficultyCurve.parameters(level: level, track: track)
                let board = LevelGenerator.fallback(level: level, track: track, parameters: parameters)
                #expect(LevelValidator.validate(board) == nil)
                #expect(board.colorCount == parameters.colors)
            }
        }
    }
}
