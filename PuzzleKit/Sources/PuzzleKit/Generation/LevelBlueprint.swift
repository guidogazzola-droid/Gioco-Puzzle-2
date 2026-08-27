import Foundation

/// The two ends of one colour on the board.
public struct Endpoints: Hashable, Codable, Sendable {
    public let start: Coordinate
    public let end: Coordinate

    public init(start: Coordinate, end: Coordinate) {
        self.start = start
        self.end = end
    }

    public func contains(_ coordinate: Coordinate) -> Bool {
        coordinate == start || coordinate == end
    }

    public func other(than coordinate: Coordinate) -> Coordinate? {
        if coordinate == start { return end }
        if coordinate == end { return start }
        return nil
    }
}

/// A fully generated, guaranteed-solvable level.
///
/// `solution` is not shown to the player - it is the path set the generator
/// built the board from. It powers hints and the "show solution" flow, and it
/// is what makes solvability a property of construction rather than of search.
public struct LevelBlueprint: Hashable, Codable, Sendable, Identifiable {

    public let level: Int
    public let track: LevelTrack
    public let width: Int
    public let height: Int
    public let blocked: Set<Coordinate>
    public let solution: [[Coordinate]]
    public let seed: UInt64

    public init(
        level: Int,
        track: LevelTrack,
        width: Int,
        height: Int,
        blocked: Set<Coordinate>,
        solution: [[Coordinate]],
        seed: UInt64
    ) {
        self.level = level
        self.track = track
        self.width = width
        self.height = height
        self.blocked = blocked
        self.solution = solution
        self.seed = seed
    }

    public var id: String { "\(track.rawValue)-\(level)-\(seed)" }

    public var colorCount: Int { solution.count }

    /// The fewest drags a perfect solve takes: one per colour.
    public var parMoves: Int { solution.count }

    public var playableCells: Int { width * height - blocked.count }

    public var endpoints: [Endpoints] {
        solution.map { Endpoints(start: $0[0], end: $0[$0.count - 1]) }
    }

    /// How many corners the intended solution turns through - the generator's
    /// proxy for how knotted a board feels.
    public var turnCount: Int {
        var total = 0
        for path in solution where path.count > 2 {
            for index in 1..<(path.count - 1) {
                let before = path[index - 1]
                let after = path[index + 1]
                if before.x != after.x && before.y != after.y { total += 1 }
            }
        }
        return total
    }

    public func contains(_ coordinate: Coordinate) -> Bool {
        coordinate.x >= 0 && coordinate.x < width
            && coordinate.y >= 0 && coordinate.y < height
    }

    public func isBlocked(_ coordinate: Coordinate) -> Bool {
        blocked.contains(coordinate)
    }

    public func isPlayable(_ coordinate: Coordinate) -> Bool {
        contains(coordinate) && !isBlocked(coordinate)
    }

    /// Colour index owning `coordinate` as an endpoint, if any.
    public func endpointColor(at coordinate: Coordinate) -> Int? {
        for (index, path) in solution.enumerated()
        where path[0] == coordinate || path[path.count - 1] == coordinate {
            return index
        }
        return nil
    }
}
