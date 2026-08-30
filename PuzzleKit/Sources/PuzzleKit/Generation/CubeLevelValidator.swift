import Foundation

/// Structural guarantees for a cubical Fieldweave level.
public enum CubeLevelValidator {
    public enum Failure: String, Sendable, Equatable {
        case invalidSide = "cube side must contain at least three tiles"
        case invalidFaces = "active faces must be unique"
        case tooFewColors = "a board needs at least three circuits"
        case emptyColor = "a circuit must cover at least two tiles"
        case selfIntersecting = "a circuit revisits one of its tiles"
        case outOfBounds = "a circuit leaves the active cube surface"
        case routedThroughWall = "a circuit crosses a blocked tile"
        case overlappingColors = "two circuits share a tile"
        case nonAdjacentStep = "a circuit makes an invalid surface step"
        case incompleteCoverage = "some playable surface tiles are uncovered"
        case noSeamCrossing = "the level never bends around a cube edge"
    }

    public static func isValid(_ blueprint: CubeLevelBlueprint) -> Bool {
        validate(blueprint) == nil
    }

    public static func validate(_ blueprint: CubeLevelBlueprint) -> Failure? {
        guard blueprint.side >= 3 else { return .invalidSide }
        guard !blueprint.activeFaces.isEmpty,
              Set(blueprint.activeFaces).count == blueprint.activeFaces.count
        else { return .invalidFaces }
        guard blueprint.solution.count >= 3 else { return .tooFewColors }

        var covered: Set<CubeCell> = []
        covered.reserveCapacity(blueprint.playableCells)

        for path in blueprint.solution {
            guard path.count >= 2 else { return .emptyColor }
            guard Set(path).count == path.count else { return .selfIntersecting }
            for cell in path {
                guard blueprint.contains(cell) else { return .outOfBounds }
                guard !blueprint.isBlocked(cell) else { return .routedThroughWall }
                guard covered.insert(cell).inserted else { return .overlappingColors }
            }
            for index in 1..<path.count
            where !CubeTopology.areAdjacent(path[index - 1], path[index], side: blueprint.side) {
                return .nonAdjacentStep
            }
        }

        guard covered.count == blueprint.playableCells else { return .incompleteCoverage }
        return blueprint.seamCrossings > 0 ? nil : .noSeamCrossing
    }
}
