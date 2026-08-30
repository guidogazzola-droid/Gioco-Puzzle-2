import Foundation

/// The two magnetic poles of one circuit on the cube.
public struct CubeEndpoints: Hashable, Codable, Sendable {
    public let start: CubeCell
    public let end: CubeCell

    public init(start: CubeCell, end: CubeCell) {
        self.start = start
        self.end = end
    }

    public func contains(_ cell: CubeCell) -> Bool {
        cell == start || cell == end
    }
}

/// A rotatable two-port element fixed to one cube tile.
public struct CubeFluxRotor: Hashable, Codable, Sendable, Identifiable {
    public let cell: CubeCell
    public let color: Int
    public let target: FluxOrientation
    public let initial: FluxOrientation

    public var id: CubeCell { cell }

    public init(
        cell: CubeCell,
        color: Int,
        target: FluxOrientation,
        initial: FluxOrientation
    ) {
        self.cell = cell
        self.color = color
        self.target = target
        self.initial = initial
    }
}

/// A guaranteed-solvable puzzle wrapped around a cube.
///
/// Every active surface tile appears exactly once in `solution`. Paths may
/// cross face seams, so one circuit can physically bend around the object.
public struct CubeLevelBlueprint: Hashable, Codable, Sendable, Identifiable {
    public let level: Int
    public let track: LevelTrack
    public let side: Int
    public let activeFaces: [CubeFace]
    public let blocked: Set<CubeCell>
    public let solution: [[CubeCell]]
    public let seed: UInt64

    public init(
        level: Int,
        track: LevelTrack,
        side: Int,
        activeFaces: [CubeFace],
        blocked: Set<CubeCell>,
        solution: [[CubeCell]],
        seed: UInt64
    ) {
        self.level = level
        self.track = track
        self.side = side
        self.activeFaces = activeFaces
        self.blocked = blocked
        self.solution = solution
        self.seed = seed
    }

    public var id: String { "cube-\(track.rawValue)-\(level)-\(seed)" }
    public var colorCount: Int { solution.count }
    public var playableCells: Int { side * side * activeFaces.count - blocked.count }
    public var endpoints: [CubeEndpoints] {
        solution.map { CubeEndpoints(start: $0[0], end: $0[$0.count - 1]) }
    }

    /// One trail gesture per circuit plus every required rotor turn.
    public var parMoves: Int {
        solution.count + fluxRotors.reduce(0) {
            $0 + $1.initial.clockwiseDistance(to: $1.target)
        }
    }

    public var seamCrossings: Int {
        solution.reduce(into: 0) { total, path in
            guard path.count > 1 else { return }
            for index in 1..<path.count where path[index - 1].face != path[index].face {
                total += 1
            }
        }
    }

    public var turnCount: Int {
        solution.reduce(into: 0) { total, path in
            guard path.count > 2 else { return }
            for index in 1..<(path.count - 1) {
                guard let first = CubeTopology.direction(
                    from: path[index], to: path[index - 1], side: side
                ), let second = CubeTopology.direction(
                    from: path[index], to: path[index + 1], side: side
                ) else { continue }
                if first.opposite != second { total += 1 }
            }
        }
    }

    /// Rotors are derived from the hidden solution, never placed speculatively.
    public var fluxRotors: [CubeFluxRotor] {
        var candidates: [(rotor: CubeFluxRotor, isCorner: Bool, rank: UInt64)] = []

        for (color, path) in solution.enumerated() where path.count >= 3 {
            for index in 1..<(path.count - 1) {
                let cell = path[index]
                guard let first = CubeTopology.direction(
                    from: cell, to: path[index - 1], side: side
                ), let second = CubeTopology.direction(
                    from: cell, to: path[index + 1], side: side
                ), let target = FluxOrientation.connecting(first, second)
                else { continue }

                let rank = rotorRank(at: cell, color: color)
                var initial = target
                let offset = 1 + Int(rank % UInt64(max(1, target.cycleLength - 1)))
                for _ in 0..<offset { initial = initial.rotatedClockwise }
                candidates.append((
                    CubeFluxRotor(
                        cell: cell,
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
            return $0.rotor.cell < $1.rotor.cell
        }
        let campaignCount = 1 + min(4, max(0, level - 1) / 14)
        let trackBonus = track == .pro ? 1 : 0
        return candidates.prefix(min(candidates.count, min(6, campaignCount + trackBonus)))
            .map(\.rotor)
    }

    public func contains(_ cell: CubeCell) -> Bool {
        activeFaces.contains(cell.face) && CubeTopology.contains(cell, side: side)
    }

    public func isBlocked(_ cell: CubeCell) -> Bool { blocked.contains(cell) }
    public func isPlayable(_ cell: CubeCell) -> Bool { contains(cell) && !isBlocked(cell) }

    public func endpointColor(at cell: CubeCell) -> Int? {
        for (color, path) in solution.enumerated()
        where path.first == cell || path.last == cell {
            return color
        }
        return nil
    }

    public func polarity(at cell: CubeCell) -> MagneticPolarity? {
        for path in solution {
            if path.first == cell { return .north }
            if path.last == cell { return .south }
        }
        return nil
    }

    public func rotor(at cell: CubeCell) -> CubeFluxRotor? {
        fluxRotors.first { $0.cell == cell }
    }

    private func rotorRank(at cell: CubeCell, color: Int) -> UInt64 {
        var value = seed
        value ^= UInt64(CubeFace.allCases.firstIndex(of: cell.face)! + 1)
            &* 0xD6E8_FEB8_6659_FD93
        value ^= UInt64(bitPattern: Int64(cell.x + 1)) &* 0x9E37_79B9_7F4A_7C15
        value ^= UInt64(bitPattern: Int64(cell.y + 1)) &* 0xBF58_476D_1CE4_E5B9
        value ^= UInt64(color + 1) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
