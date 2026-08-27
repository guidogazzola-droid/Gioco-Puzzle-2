import Testing
@testable import PuzzleKit

/// Hand-built boards for rule tests that need an exact, readable layout.
/// Generated boards are the right subject for the generator's own tests, but a
/// rule test should not depend on what a seed happened to produce.
enum TestBoards {

    /// A 3x3 board covered by three colours:
    ///
    ///     A B B
    ///     a C b
    ///     A c C
    ///
    /// Colour 0 runs down the left column, colour 1 hooks across the top right,
    /// colour 2 fills the rest. Colour 0's endpoint at (0,0) sits next to
    /// colour 1's endpoint at (1,0), which is what makes it useful for testing
    /// that foreign endpoints are impassable.
    static let trio = LevelBlueprint(
        level: 1,
        track: .free,
        width: 3,
        height: 3,
        blocked: [],
        solution: [
            [Coordinate(0, 0), Coordinate(0, 1), Coordinate(0, 2)],
            [Coordinate(1, 0), Coordinate(2, 0), Coordinate(2, 1)],
            [Coordinate(1, 1), Coordinate(1, 2), Coordinate(2, 2)]
        ],
        seed: 0
    )

    /// The same board with the centre column walled off, so only two colours
    /// remain reachable - used to check that walls are impassable.
    static let walled = LevelBlueprint(
        level: 1,
        track: .pro,
        width: 3,
        height: 3,
        blocked: [Coordinate(1, 1)],
        solution: [
            [Coordinate(0, 0), Coordinate(0, 1), Coordinate(0, 2)],
            [Coordinate(1, 0), Coordinate(2, 0), Coordinate(2, 1)],
            [Coordinate(1, 2), Coordinate(2, 2)]
        ],
        seed: 0
    )
}

struct TestBoardTests {

    @Test("the hand-built fixtures are themselves valid boards")
    func fixturesAreValid() {
        #expect(LevelValidator.validate(TestBoards.trio) == nil)
        #expect(LevelValidator.validate(TestBoards.walled) == nil)
    }

    @Test("the validator rejects each way a board can be broken")
    func validatorCatchesBreakage() {
        func board(_ solution: [[Coordinate]], blocked: Set<Coordinate> = []) -> LevelBlueprint {
            LevelBlueprint(level: 1, track: .free, width: 3, height: 3,
                           blocked: blocked, solution: solution, seed: 0)
        }
        let good = TestBoards.trio.solution

        // A cell nobody covers.
        var short = good
        short[2] = [Coordinate(1, 1), Coordinate(1, 2)]
        #expect(LevelValidator.validate(board(short)) == .incompleteCoverage)

        // Two colours on the same cell.
        var overlapping = good
        overlapping[1] = [Coordinate(0, 0), Coordinate(1, 0), Coordinate(2, 0)]
        #expect(LevelValidator.validate(board(overlapping)) == .overlappingColors)

        // A colour that teleports.
        var jumping = good
        jumping[0] = [Coordinate(0, 0), Coordinate(0, 2)]
        #expect(LevelValidator.validate(board(jumping)) == .nonOrthogonalStep)

        // A colour that runs off the board.
        var escaping = good
        escaping[0] = [Coordinate(0, 0), Coordinate(0, 1), Coordinate(0, 2), Coordinate(0, 3)]
        #expect(LevelValidator.validate(board(escaping)) == .outOfBounds)

        // A colour routed through a wall.
        #expect(LevelValidator.validate(board(good, blocked: [Coordinate(1, 1)])) == .routedThroughWall)

        // Not enough colours to make a puzzle.
        #expect(LevelValidator.validate(board(Array(good.prefix(2)))) == .tooFewColors)
    }
}
