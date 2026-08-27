import Foundation

/// A cell on the puzzle board. Origin is the top-left corner.
public struct Coordinate: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {

    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Orthogonal neighbours, in a fixed order so generation stays reproducible.
    public func neighbours(width: Int, height: Int) -> [Coordinate] {
        var result: [Coordinate] = []
        result.reserveCapacity(4)
        if y > 0 { result.append(Coordinate(x, y - 1)) }
        if x > 0 { result.append(Coordinate(x - 1, y)) }
        if x + 1 < width { result.append(Coordinate(x + 1, y)) }
        if y + 1 < height { result.append(Coordinate(x, y + 1)) }
        return result
    }

    public func isAdjacent(to other: Coordinate) -> Bool {
        abs(x - other.x) + abs(y - other.y) == 1
    }

    public static func < (lhs: Coordinate, rhs: Coordinate) -> Bool {
        lhs.x == rhs.x ? lhs.y < rhs.y : lhs.x < rhs.x
    }

    public var description: String { "(\(x),\(y))" }
}

/// The four orthogonal directions, used for drawing pipe joints.
public enum Direction: Int, CaseIterable, Sendable, Codable {
    case up, left, right, down

    public var delta: Coordinate {
        switch self {
        case .up:    Coordinate(0, -1)
        case .left:  Coordinate(-1, 0)
        case .right: Coordinate(1, 0)
        case .down:  Coordinate(0, 1)
        }
    }

    public var opposite: Direction {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }

    public static func between(_ from: Coordinate, _ to: Coordinate) -> Direction? {
        switch (to.x - from.x, to.y - from.y) {
        case (0, -1): .up
        case (0, 1):  .down
        case (-1, 0): .left
        case (1, 0):  .right
        default:      nil
        }
    }
}
