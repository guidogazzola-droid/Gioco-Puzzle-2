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
