import Foundation

/// The playable state of one board: circuit routes, magnetic rotor alignment,
/// and what a drag is allowed to do next.
///
/// The engine is a plain value type with no UI or timing concerns, which is why
/// every rule below is directly unit-testable.
public struct PuzzleEngine: Sendable {

    public let blueprint: LevelBlueprint

    /// The player's current path per colour, indexed by colour.
    public private(set) var paths: [[Coordinate]]
    /// Completed drags that changed the board. `blueprint.parMoves` is perfect.
    public private(set) var moves: Int = 0
    /// Hints spent on this attempt - they cap the star award.
    public private(set) var hintsUsed: Int = 0
    public private(set) var activeColor: Int?
    /// Current orientation of every field rotor, keyed by board coordinate.
    public private(set) var rotorOrientations: [Coordinate: FluxOrientation]

    private var occupancy: [Coordinate: Int] = [:]
    private let endpointOwners: [Coordinate: Int]
    private let rotorsByCoordinate: [Coordinate: FluxRotor]
    private var dragChangedBoard = false

    public init(blueprint: LevelBlueprint) {
        self.blueprint = blueprint
        self.paths = Array(repeating: [], count: blueprint.colorCount)

        var owners: [Coordinate: Int] = [:]
        for (index, path) in blueprint.solution.enumerated() {
            owners[path[0]] = index
            owners[path[path.count - 1]] = index
        }
        self.endpointOwners = owners
        self.rotorsByCoordinate = Dictionary(
            uniqueKeysWithValues: blueprint.fluxRotors.map { ($0.coordinate, $0) }
        )
        self.rotorOrientations = Dictionary(
            uniqueKeysWithValues: blueprint.fluxRotors.map { ($0.coordinate, $0.initial) }
        )
    }

    // MARK: - Queries

    public var colorCount: Int { blueprint.colorCount }
    public var parMoves: Int { blueprint.parMoves }
    public var filledCells: Int { occupancy.count }

    public var completionRatio: Double {
        guard blueprint.playableCells > 0 else { return 1 }
        return Double(occupancy.count) / Double(blueprint.playableCells)
    }

    public func color(at cell: Coordinate) -> Int? { occupancy[cell] }

    public func endpointColor(at cell: Coordinate) -> Int? { endpointOwners[cell] }

    /// A colour is connected once its path runs endpoint to endpoint.
    public func isConnected(color: Int) -> Bool {
        let path = paths[color]
        guard path.count >= 2 else { return false }
        let ends = blueprint.solution[color]
        return path[0] == ends[0] && path[path.count - 1] == ends[ends.count - 1]
    }

    public var connectedColors: Int {
        (0..<colorCount).filter { isConnected(color: $0) }.count
    }

    public var totalRotors: Int { rotorsByCoordinate.count }

    public var alignedRotors: Int {
        rotorsByCoordinate.values.reduce(into: 0) { count, rotor in
            if rotorOrientations[rotor.coordinate] == rotor.target { count += 1 }
        }
    }

    public var fieldStability: Double {
        guard totalRotors > 0 else { return 1 }
        return Double(alignedRotors) / Double(totalRotors)
    }

    public func rotor(at cell: Coordinate) -> FluxRotor? { rotorsByCoordinate[cell] }

    public func rotorOrientation(at cell: Coordinate) -> FluxOrientation? {
        rotorOrientations[cell]
    }

    public func isRotorAligned(at cell: Coordinate) -> Bool {
        guard let rotor = rotorsByCoordinate[cell] else { return false }
        return rotorOrientations[cell] == rotor.target
    }

    /// The win condition: every colour connected *and* every cell covered.
    /// Requiring full coverage is what makes the puzzle interesting - without
    /// it, most boards collapse to straight lines.
    public var isSolved: Bool {
        occupancy.count == blueprint.playableCells
            && (0..<colorCount).allSatisfy { isConnected(color: $0) }
            && alignedRotors == totalRotors
    }

    // MARK: - Dragging

    /// Starts a drag. Grabbing an endpoint restarts that colour; grabbing a
    /// cell mid-path rewinds the colour to that cell and continues from there.
    @discardableResult
    public mutating func beginDrag(at cell: Coordinate) -> Bool {
        guard blueprint.isPlayable(cell) else { return false }

        if let color = endpointOwners[cell] {
            // A circuit is directional: energy leaves N and reaches S.
            guard blueprint.polarity(at: cell) == .north else { return false }
            dragChangedBoard = !paths[color].isEmpty
            clearPath(color: color)
            paths[color] = [cell]
            occupancy[cell] = color
            activeColor = color
            return true
        }

        if let color = occupancy[cell], let index = paths[color].firstIndex(of: cell) {
            truncate(color: color, keepingThrough: index)
            dragChangedBoard = true
            activeColor = color
            return true
        }

        return false
    }

    /// Extends the active drag onto `cell`. Returns `false` when the move is
    /// not legal, so the caller can decide whether to buzz.
    @discardableResult
    public mutating func extendDrag(to cell: Coordinate) -> Bool {
        guard let color = activeColor,
              blueprint.isPlayable(cell),
              let head = paths[color].last,
              head.isAdjacent(to: cell)
        else { return false }

        // Backtracking over the previous cell rewinds one step.
        let path = paths[color]
        if path.count >= 2 && path[path.count - 2] == cell {
            truncate(color: color, keepingThrough: path.count - 2)
            dragChangedBoard = true
            return true
        }

        // A finished colour is locked: it cannot be dragged past its endpoint.
        if isConnected(color: color) { return false }

        // Another colour's endpoint is never passable.
        if let owner = endpointOwners[cell], owner != color { return false }

        // A rotor belongs to one circuit and exposes exactly two ports. Both
        // sides of this edge must be open before the trail can advance.
        guard magneticEdgeIsOpen(from: head, to: cell, color: color) else { return false }

        if let occupant = occupancy[cell] {
            if occupant == color {
                // Crossing our own trail rewinds to the crossing point.
                guard let index = path.firstIndex(of: cell) else { return false }
                truncate(color: color, keepingThrough: index)
                dragChangedBoard = true
                return true
            }
            // Cutting into another colour truncates it - the Flow convention.
            guard let index = paths[occupant].firstIndex(of: cell) else { return false }
            truncate(color: occupant, keepingThrough: index - 1)
        }

        paths[color].append(cell)
        occupancy[cell] = color
        dragChangedBoard = true
        return true
    }

    /// Ends the drag and books a move if the board actually changed.
    public mutating func endDrag() {
        activeColor = nil
        if dragChangedBoard {
            moves += 1
            dragChangedBoard = false
        }
    }

    // MARK: - Board actions

    /// Turns one field rotor clockwise. Rotor turns are scored actions, so the
    /// magnetic setup is part of par instead of free decoration.
    @discardableResult
    public mutating func rotateRotor(at cell: Coordinate) -> Bool {
        guard activeColor == nil,
              rotorsByCoordinate[cell] != nil,
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
        rotorOrientations = Dictionary(
            uniqueKeysWithValues: rotorsByCoordinate.values.map { ($0.coordinate, $0.initial) }
        )
    }

    /// Solves one colour outright. Returns the colour that was revealed, or
    /// `nil` when the board is already complete.
    @discardableResult
    public mutating func revealHint() -> Int? {
        guard let color = (0..<colorCount).first(where: { !isConnected(color: $0) })
            ?? (0..<colorCount).first(where: { paths[$0] != blueprint.solution[$0] })
            ?? (0..<colorCount).first(where: { color in
                rotorsByCoordinate.values.contains {
                    $0.color == color && rotorOrientations[$0.coordinate] != $0.target
                }
            })
        else { return nil }

        apply(solutionFor: color)
        hintsUsed += 1
        moves += 1
        return color
    }

    /// Fills in the whole intended solution - used by the "show solution" flow
    /// that a rewarded ad or a Pro subscription unlocks.
    public mutating func revealSolution() {
        for color in 0..<colorCount { apply(solutionFor: color) }
        hintsUsed += colorCount
    }

    // MARK: - Internals

    private mutating func apply(solutionFor color: Int) {
        let solution = blueprint.solution[color]
        // Vacate anything standing on the intended route first.
        for cell in solution {
            if let occupant = occupancy[cell], occupant != color,
               let index = paths[occupant].firstIndex(of: cell) {
                truncate(color: occupant, keepingThrough: index - 1)
            }
        }
        clearPath(color: color)
        paths[color] = solution
        for cell in solution { occupancy[cell] = color }
        for rotor in rotorsByCoordinate.values where rotor.color == color {
            rotorOrientations[rotor.coordinate] = rotor.target
        }
    }

    private func magneticEdgeIsOpen(from: Coordinate, to: Coordinate, color: Int) -> Bool {
        guard let outward = FieldDirection.between(from, to) else { return false }

        if let rotor = rotorsByCoordinate[from] {
            guard rotor.color == color,
                  rotorOrientations[from]?.ports.contains(outward) == true
            else { return false }
        }

        if let rotor = rotorsByCoordinate[to] {
            guard rotor.color == color,
                  rotorOrientations[to]?.ports.contains(outward.opposite) == true
            else { return false }
        }
        return true
    }

    private mutating func clearPath(color: Int) {
        for cell in paths[color] where occupancy[cell] == color {
            occupancy[cell] = nil
        }
        paths[color] = []
    }

    /// Keeps `paths[color][0...index]`; a negative index clears the colour.
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
