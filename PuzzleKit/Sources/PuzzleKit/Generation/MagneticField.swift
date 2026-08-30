import Foundation

/// The four ports a magnetic rotor can expose to neighbouring cells.
public enum FieldDirection: Int, CaseIterable, Codable, Sendable, Hashable {
    case north
    case east
    case south
    case west

    public var opposite: FieldDirection {
        switch self {
        case .north: .south
        case .east: .west
        case .south: .north
        case .west: .east
        }
    }

    /// Direction from one orthogonally adjacent cell to the other.
    public static func between(_ origin: Coordinate, _ neighbour: Coordinate) -> FieldDirection? {
        switch (neighbour.x - origin.x, neighbour.y - origin.y) {
        case (0, -1): .north
        case (1, 0): .east
        case (0, 1): .south
        case (-1, 0): .west
        default: nil
        }
    }
}

/// Every circuit has a fixed direction: energy leaves N and must reach S.
public enum MagneticPolarity: String, Codable, Sendable, Hashable {
    case north = "N"
    case south = "S"
}

/// The six useful two-port orientations of a rotor.
///
/// Straight rotors have a two-position cycle; elbow rotors have a four-position
/// cycle. Keeping those cycles separate makes every tap read as a physical
/// quarter-turn instead of cycling through unrelated pieces.
public enum FluxOrientation: String, Codable, Sendable, Hashable {
    case horizontal
    case vertical
    case northEast
    case southEast
    case southWest
    case northWest

    public var ports: Set<FieldDirection> {
        switch self {
        case .horizontal: [.east, .west]
        case .vertical: [.north, .south]
        case .northEast: [.north, .east]
        case .southEast: [.south, .east]
        case .southWest: [.south, .west]
        case .northWest: [.north, .west]
        }
    }

    public var cycleLength: Int {
        switch self {
        case .horizontal, .vertical: 2
        default: 4
        }
    }

    public var rotatedClockwise: FluxOrientation {
        switch self {
        case .horizontal: .vertical
        case .vertical: .horizontal
        case .northEast: .southEast
        case .southEast: .southWest
        case .southWest: .northWest
        case .northWest: .northEast
        }
    }

    public func clockwiseDistance(to target: FluxOrientation) -> Int {
        var value = self
        for steps in 0..<cycleLength {
            if value == target { return steps }
            value = value.rotatedClockwise
        }
        return cycleLength
    }

    /// The rotor shape that connects `previous` to `next` through `cell`.
    public static func connecting(
        previous: Coordinate,
        through cell: Coordinate,
        next: Coordinate
    ) -> FluxOrientation? {
        guard let first = FieldDirection.between(cell, previous),
              let second = FieldDirection.between(cell, next)
        else { return nil }

        return connecting(first, second)
    }

    /// The rotor shape exposing two local ports. Cube cells use the same six
    /// physical pieces as flat cells; only their face-local directions differ.
    public static func connecting(
        _ first: FieldDirection,
        _ second: FieldDirection
    ) -> FluxOrientation? {
        guard first != second else { return nil }

        let ports: Set<FieldDirection> = [first, second]
        if ports == [.east, .west] { return .horizontal }
        if ports == [.north, .south] { return .vertical }
        if ports == [.north, .east] { return .northEast }
        if ports == [.south, .east] { return .southEast }
        if ports == [.south, .west] { return .southWest }
        if ports == [.north, .west] { return .northWest }
        return nil
    }
}

/// One rotatable field element embedded in a circuit's intended route.
public struct FluxRotor: Hashable, Codable, Sendable, Identifiable {
    public let coordinate: Coordinate
    public let color: Int
    public let target: FluxOrientation
    public let initial: FluxOrientation

    public var id: Coordinate { coordinate }

    public init(
        coordinate: Coordinate,
        color: Int,
        target: FluxOrientation,
        initial: FluxOrientation
    ) {
        self.coordinate = coordinate
        self.color = color
        self.target = target
        self.initial = initial
    }
}
