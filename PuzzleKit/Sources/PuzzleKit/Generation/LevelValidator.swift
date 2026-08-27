import Foundation

/// The invariants a Line Flow SW board must satisfy to be playable.
///
/// Every generated blueprint is checked against these before it is handed to
/// the player, so an unsolvable level cannot reach the App Store even if the
/// generator is later changed.
public enum LevelValidator {

    public enum Failure: String, Sendable, Equatable {
        case tooFewColors        = "a board needs at least three colours"
        case emptyColor          = "a colour must cover at least two cells"
        case selfIntersecting    = "a colour revisits one of its own cells"
        case outOfBounds         = "a colour leaves the board"
        case routedThroughWall   = "a colour is routed through a wall"
        case overlappingColors   = "two colours share a cell"
        case nonOrthogonalStep   = "a colour makes a non-orthogonal step"
        case incompleteCoverage  = "some playable cells are not covered"
    }

    public static func isValid(_ blueprint: LevelBlueprint) -> Bool {
        validate(blueprint) == nil
    }

    /// Returns the first violated invariant, or `nil` when the board is sound.
    public static func validate(_ blueprint: LevelBlueprint) -> Failure? {
        guard blueprint.solution.count >= 3 else { return .tooFewColors }

        var covered: Set<Coordinate> = []
        covered.reserveCapacity(blueprint.playableCells)

        for path in blueprint.solution {
            guard path.count >= 2 else { return .emptyColor }
            if Set(path).count != path.count { return .selfIntersecting }

            for cell in path {
                guard blueprint.contains(cell) else { return .outOfBounds }
                guard !blueprint.isBlocked(cell) else { return .routedThroughWall }
                guard covered.insert(cell).inserted else { return .overlappingColors }
            }
            for index in 1..<path.count where !path[index - 1].isAdjacent(to: path[index]) {
                return .nonOrthogonalStep
            }
        }

        return covered.count == blueprint.playableCells ? nil : .incompleteCoverage
    }
}
