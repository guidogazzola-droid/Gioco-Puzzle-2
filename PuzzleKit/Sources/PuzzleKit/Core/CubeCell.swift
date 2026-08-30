import Foundation

/// The six outward-facing planes of the Fieldweave cube.
public enum CubeFace: String, CaseIterable, Codable, Sendable, Hashable, Comparable {
    case front
    case right
    case back
    case left
    case top
    case bottom

    public static func < (lhs: CubeFace, rhs: CubeFace) -> Bool {
        order(of: lhs) < order(of: rhs)
    }

    private static func order(of face: CubeFace) -> Int {
        switch face {
        case .front: 0
        case .right: 1
        case .back: 2
        case .left: 3
        case .top: 4
        case .bottom: 5
        }
    }

    /// Integer basis vectors keep every seam transform exact and reversible.
    public var normal: CubeAxis {
        switch self {
        case .front: CubeAxis(0, 0, 1)
        case .right: CubeAxis(1, 0, 0)
        case .back: CubeAxis(0, 0, -1)
        case .left: CubeAxis(-1, 0, 0)
        case .top: CubeAxis(0, 1, 0)
        case .bottom: CubeAxis(0, -1, 0)
        }
    }

    /// Screen-right when this face is viewed straight on from outside.
    public var rightAxis: CubeAxis {
        switch self {
        case .front: CubeAxis(1, 0, 0)
        case .right: CubeAxis(0, 0, -1)
        case .back: CubeAxis(-1, 0, 0)
        case .left: CubeAxis(0, 0, 1)
        case .top, .bottom: CubeAxis(1, 0, 0)
        }
    }

    /// Screen-down when this face is viewed straight on from outside.
    public var downAxis: CubeAxis {
        switch self {
        case .front, .right, .back, .left: CubeAxis(0, -1, 0)
        case .top: CubeAxis(0, 0, 1)
        case .bottom: CubeAxis(0, 0, -1)
        }
    }

    static func with(normal: CubeAxis) -> CubeFace? {
        allCases.first { $0.normal == normal }
    }
}

/// One of the cube's signed world axes.
public struct CubeAxis: Hashable, Codable, Sendable {
    public let x: Int
    public let y: Int
    public let z: Int

    public init(_ x: Int, _ y: Int, _ z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    static prefix func - (value: CubeAxis) -> CubeAxis {
        CubeAxis(-value.x, -value.y, -value.z)
    }

    static func + (lhs: CubeAxis, rhs: CubeAxis) -> CubeAxis {
        CubeAxis(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: CubeAxis, rhs: CubeAxis) -> CubeAxis {
        CubeAxis(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: CubeAxis, rhs: Int) -> CubeAxis {
        CubeAxis(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    func dot(_ other: CubeAxis) -> Int {
        x * other.x + y * other.y + z * other.z
    }
}

/// A grid cell on one face of a cube.
public struct CubeCell: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let face: CubeFace
    public var x: Int
    public var y: Int

    public init(face: CubeFace, x: Int, y: Int) {
        self.face = face
        self.x = x
        self.y = y
    }

    public static func < (lhs: CubeCell, rhs: CubeCell) -> Bool {
        if lhs.face != rhs.face { return lhs.face < rhs.face }
        return lhs.x == rhs.x ? lhs.y < rhs.y : lhs.x < rhs.x
    }

    public var description: String { "\(face.rawValue):(\(x),\(y))" }

    public func neighbour(in direction: FieldDirection, side: Int) -> CubeCell? {
        CubeTopology.neighbour(of: self, in: direction, side: side)
    }

    public func neighbours(side: Int) -> [CubeCell] {
        [.north, .west, .east, .south].compactMap { neighbour(in: $0, side: side) }
    }
}

/// Exact cube-folding rules shared by generation, gameplay and rendering.
public enum CubeTopology {

    public static func contains(_ cell: CubeCell, side: Int) -> Bool {
        side > 0 && cell.x >= 0 && cell.x < side && cell.y >= 0 && cell.y < side
    }

    public static func neighbour(
        of cell: CubeCell,
        in direction: FieldDirection,
        side: Int
    ) -> CubeCell? {
        guard contains(cell, side: side) else { return nil }

        let localX: Int
        let localY: Int
        switch direction {
        case .north: (localX, localY) = (cell.x, cell.y - 1)
        case .east: (localX, localY) = (cell.x + 1, cell.y)
        case .south: (localX, localY) = (cell.x, cell.y + 1)
        case .west: (localX, localY) = (cell.x - 1, cell.y)
        }
        if localX >= 0, localX < side, localY >= 0, localY < side {
            return CubeCell(face: cell.face, x: localX, y: localY)
        }

        let face = cell.face
        let movement: CubeAxis
        switch direction {
        case .north: movement = -face.downAxis
        case .east: movement = face.rightAxis
        case .south: movement = face.downAxis
        case .west: movement = -face.rightAxis
        }
        guard let destinationFace = CubeFace.with(normal: movement) else { return nil }

        // Cell centres are two grid units apart. Across a folded edge the
        // centre-to-centre vector is `movement - oldNormal`, which turns the
        // corner instead of teleporting through the cube.
        let position = surfacePosition(of: cell, side: side)
        let destination = position + movement - face.normal
        let u = destination.dot(destinationFace.rightAxis)
        let v = destination.dot(destinationFace.downAxis)
        let x = (u + side - 1) / 2
        let y = (v + side - 1) / 2
        let result = CubeCell(face: destinationFace, x: x, y: y)
        return contains(result, side: side) ? result : nil
    }

    public static func direction(
        from origin: CubeCell,
        to neighbour: CubeCell,
        side: Int
    ) -> FieldDirection? {
        FieldDirection.allCases.first {
            self.neighbour(of: origin, in: $0, side: side) == neighbour
        }
    }

    public static func areAdjacent(_ first: CubeCell, _ second: CubeCell, side: Int) -> Bool {
        direction(from: first, to: second, side: side) != nil
    }

    public static func crossesSeam(_ first: CubeCell, _ second: CubeCell) -> Bool {
        first.face != second.face
    }

    /// Integer world position of a cell centre on the cube surface.
    /// Dividing by `2 * side` produces renderer-friendly unit coordinates.
    public static func surfacePosition(of cell: CubeCell, side: Int) -> CubeAxis {
        let u = 2 * cell.x + 1 - side
        let v = 2 * cell.y + 1 - side
        return cell.face.normal * side
            + cell.face.rightAxis * u
            + cell.face.downAxis * v
    }
}
