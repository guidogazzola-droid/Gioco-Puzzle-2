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

    /// The fewest actions a perfect solve takes: one drag per circuit plus the
    /// required clockwise turns of every magnetic rotor.
    public var parMoves: Int {
        solution.count + fluxRotors.reduce(0) {
            $0 + $1.initial.clockwiseDistance(to: $1.target)
        }
    }

    public var playableCells: Int { width * height - blocked.count }

    public var endpoints: [Endpoints] {
        solution.map { Endpoints(start: $0[0], end: $0[$0.count - 1]) }
    }

    /// Rotors are derived from the hidden covering, so they are deterministic
    /// and guaranteed to have a valid orientation. Early boards introduce one;
    /// later boards layer up to five into the field.
    public var fluxRotors: [FluxRotor] {
        var candidates: [(rotor: FluxRotor, isCorner: Bool, rank: UInt64)] = []

        for (color, path) in solution.enumerated() where path.count >= 3 {
            for index in 1..<(path.count - 1) {
                guard let target = FluxOrientation.connecting(
                    previous: path[index - 1], through: path[index], next: path[index + 1]
                ) else { continue }

                let coordinate = path[index]
                let rank = rotorRank(at: coordinate, color: color)
                var initial = target
                let offset = 1 + Int(rank % UInt64(max(1, target.cycleLength - 1)))
                for _ in 0..<offset { initial = initial.rotatedClockwise }

                candidates.append((
                    FluxRotor(
                        coordinate: coordinate,
                        color: color,
                        target: target,
                        initial: initial
                    ),
                    target.cycleLength == 4,
                    rank
                ))
            }
        }

        candidates.sort {
            if $0.isCorner != $1.isCorner { return $0.isCorner && !$1.isCorner }
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.rotor.coordinate < $1.rotor.coordinate
        }

        let campaignCount = 1 + min(3, max(0, level - 1) / 15)
        let trackBonus = track == .pro ? 1 : 0
        let count = min(candidates.count, min(5, campaignCount + trackBonus))
        return candidates.prefix(count).map { $0.rotor }
    }

    public func fluxRotor(at coordinate: Coordinate) -> FluxRotor? {
        fluxRotors.first { $0.coordinate == coordinate }
    }

    /// Start poles are N and destination poles are S. This gives every circuit
    /// a direction instead of treating the two coloured ends as interchangeable.
    public func polarity(at coordinate: Coordinate) -> MagneticPolarity? {
        for path in solution {
            if path[0] == coordinate { return .north }
            if path[path.count - 1] == coordinate { return .south }
        }
        return nil
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

    private func rotorRank(at coordinate: Coordinate, color: Int) -> UInt64 {
        var value = seed
        value ^= UInt64(bitPattern: Int64(coordinate.x + 1)) &* 0x9E37_79B9_7F4A_7C15
        value ^= UInt64(bitPattern: Int64(coordinate.y + 1)) &* 0xBF58_476D_1CE4_E5B9
        value ^= UInt64(color + 1) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
