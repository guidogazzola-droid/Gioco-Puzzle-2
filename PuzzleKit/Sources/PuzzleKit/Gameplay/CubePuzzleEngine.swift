import Foundation

/// Pure gameplay state for one cubical Fieldweave board.
public struct CubePuzzleEngine: Sendable {
    public let blueprint: CubeLevelBlueprint
    public private(set) var paths: [[CubeCell]]
    public private(set) var moves = 0
    public private(set) var hintsUsed = 0
    public private(set) var activeColor: Int?
    public private(set) var rotorOrientations: [CubeCell: FluxOrientation]

    private var occupancy: [CubeCell: Int] = [:]
    private let endpointOwners: [CubeCell: Int]
    private let rotorsByCell: [CubeCell: CubeFluxRotor]
    private var dragChangedBoard = false
    private var dragCountsAsMove = true

    public init(blueprint: CubeLevelBlueprint) {
        self.blueprint = blueprint
        self.paths = Array(repeating: [], count: blueprint.colorCount)
        var owners: [CubeCell: Int] = [:]
        for (color, path) in blueprint.solution.enumerated() {
            owners[path[0]] = color
            owners[path[path.count - 1]] = color
        }
        self.endpointOwners = owners
        self.rotorsByCell = Dictionary(
            uniqueKeysWithValues: blueprint.fluxRotors.map { ($0.cell, $0) }
        )
        self.rotorOrientations = Dictionary(
            uniqueKeysWithValues: blueprint.fluxRotors.map { ($0.cell, $0.initial) }
        )
    }

    public var colorCount: Int { blueprint.colorCount }
    public var parMoves: Int { blueprint.parMoves }
    public var filledCells: Int { occupancy.count }
    public var completionRatio: Double {
        guard blueprint.playableCells > 0 else { return 1 }
        return Double(filledCells) / Double(blueprint.playableCells)
    }

    public func color(at cell: CubeCell) -> Int? { occupancy[cell] }
    public func endpointColor(at cell: CubeCell) -> Int? { endpointOwners[cell] }

    public func isConnected(color: Int) -> Bool {
        guard paths.indices.contains(color) else { return false }
        let path = paths[color]
        let target = blueprint.solution[color]
        return path.count >= 2 && path.first == target.first && path.last == target.last
    }

    public var connectedColors: Int {
        paths.indices.filter { isConnected(color: $0) }.count
    }

    public var totalRotors: Int { rotorsByCell.count }
    public var alignedRotors: Int {
        rotorsByCell.values.reduce(into: 0) { count, rotor in
            if rotorOrientations[rotor.cell] == rotor.target { count += 1 }
        }
    }

    public var fieldStability: Double {
        totalRotors == 0 ? 1 : Double(alignedRotors) / Double(totalRotors)
    }

    public func rotor(at cell: CubeCell) -> CubeFluxRotor? { rotorsByCell[cell] }
    public func rotorOrientation(at cell: CubeCell) -> FluxOrientation? {
        rotorOrientations[cell]
    }
    public func isRotorAligned(at cell: CubeCell) -> Bool {
        guard let rotor = rotorsByCell[cell] else { return false }
        return rotorOrientations[cell] == rotor.target
    }

    public var isSolved: Bool {
        occupancy.count == blueprint.playableCells
            && paths.indices.allSatisfy { isConnected(color: $0) }
            && alignedRotors == totalRotors
    }

    // MARK: - Trail input

    @discardableResult
    public mutating func beginDrag(at cell: CubeCell) -> Bool {
        guard blueprint.isPlayable(cell) else { return false }
        if let color = endpointOwners[cell] {
            guard blueprint.polarity(at: cell) == .north else { return false }
            dragChangedBoard = !paths[color].isEmpty
            clearPath(color: color)
            paths[color] = [cell]
            occupancy[cell] = color
            activeColor = color
            dragCountsAsMove = true
            return true
        }
        if let color = occupancy[cell], let index = paths[color].firstIndex(of: cell) {
            let resumesLooseEnd = index == paths[color].count - 1 && !isConnected(color: color)
            truncate(color: color, keepingThrough: index)
            dragChangedBoard = !resumesLooseEnd
            // A path can span more faces than are visible at once. Lifting a
            // finger, rotating the cube, then continuing from the loose end is
            // still the same circuit action and must not make par impossible.
            dragCountsAsMove = !resumesLooseEnd
            activeColor = color
            return true
        }
        return false
    }

    @discardableResult
    public mutating func extendDrag(to cell: CubeCell) -> Bool {
        guard let color = activeColor,
              blueprint.isPlayable(cell),
              let head = paths[color].last,
              CubeTopology.areAdjacent(head, cell, side: blueprint.side)
        else { return false }

        let path = paths[color]
        if path.count >= 2 && path[path.count - 2] == cell {
            truncate(color: color, keepingThrough: path.count - 2)
            dragChangedBoard = true
            return true
        }
        if isConnected(color: color) { return false }
        if let owner = endpointOwners[cell], owner != color { return false }
        guard magneticEdgeIsOpen(from: head, to: cell, color: color) else { return false }

        if let occupant = occupancy[cell] {
            if occupant == color {
                guard let index = path.firstIndex(of: cell) else { return false }
                truncate(color: color, keepingThrough: index)
                dragChangedBoard = true
                return true
            }
            guard let index = paths[occupant].firstIndex(of: cell) else { return false }
            truncate(color: occupant, keepingThrough: index - 1)
        }

        paths[color].append(cell)
        occupancy[cell] = color
        dragChangedBoard = true
        return true
    }

    public mutating func endDrag() {
        activeColor = nil
        if dragChangedBoard && dragCountsAsMove {
            moves += 1
        }
        dragChangedBoard = false
        dragCountsAsMove = true
    }

    // MARK: - Actions

    @discardableResult
    public mutating func rotateRotor(at cell: CubeCell) -> Bool {
        guard activeColor == nil,
              rotorsByCell[cell] != nil,
              occupancy[cell] == nil,
              let orientation = rotorOrientations[cell]
        else { return false }
        rotorOrientations[cell] = orientation.rotatedClockwise
        moves += 1
        return true
    }

    public mutating func clear(color: Int) {
        guard paths.indices.contains(color), !paths[color].isEmpty else { return }
        clearPath(color: color)
        moves += 1
    }

    public mutating func reset() {
        for color in paths.indices { clearPath(color: color) }
        moves = 0
        hintsUsed = 0
        activeColor = nil
        dragChangedBoard = false
        dragCountsAsMove = true
        rotorOrientations = Dictionary(
            uniqueKeysWithValues: rotorsByCell.values.map { ($0.cell, $0.initial) }
        )
    }

    @discardableResult
    public mutating func revealHint() -> Int? {
        guard let color = paths.indices.first(where: { !isConnected(color: $0) })
            ?? paths.indices.first(where: { paths[$0] != blueprint.solution[$0] })
            ?? paths.indices.first(where: { color in
                rotorsByCell.values.contains {
                    $0.color == color && rotorOrientations[$0.cell] != $0.target
                }
            })
        else { return nil }
        apply(solutionFor: color)
        hintsUsed += 1
        moves += 1
        return color
    }

    public mutating func revealSolution() {
        for color in paths.indices { apply(solutionFor: color) }
        hintsUsed += colorCount
    }

    // MARK: - Internals

    private mutating func apply(solutionFor color: Int) {
        let solution = blueprint.solution[color]
        for cell in solution {
            if let occupant = occupancy[cell], occupant != color,
               let index = paths[occupant].firstIndex(of: cell) {
                truncate(color: occupant, keepingThrough: index - 1)
            }
        }
        clearPath(color: color)
        paths[color] = solution
        for cell in solution { occupancy[cell] = color }
        for rotor in rotorsByCell.values where rotor.color == color {
            rotorOrientations[rotor.cell] = rotor.target
        }
    }

    private func magneticEdgeIsOpen(from: CubeCell, to: CubeCell, color: Int) -> Bool {
        guard let outward = CubeTopology.direction(
            from: from, to: to, side: blueprint.side
        ), let inward = CubeTopology.direction(
            from: to, to: from, side: blueprint.side
        ) else { return false }

        if let rotor = rotorsByCell[from] {
            guard rotor.color == color,
                  rotorOrientations[from]?.ports.contains(outward) == true
            else { return false }
        }
        if let rotor = rotorsByCell[to] {
            guard rotor.color == color,
                  rotorOrientations[to]?.ports.contains(inward) == true
            else { return false }
        }
        return true
    }

    private mutating func clearPath(color: Int) {
        for cell in paths[color] where occupancy[cell] == color { occupancy[cell] = nil }
        paths[color] = []
    }

    private mutating func truncate(color: Int, keepingThrough index: Int) {
        guard index >= 0 else {
            clearPath(color: color)
            return
        }
        let path = paths[color]
        guard index < path.count - 1 else { return }
        for cell in path[(index + 1)...] where occupancy[cell] == color {
            occupancy[cell] = nil
        }
        paths[color] = Array(path[0...index])
    }
}
