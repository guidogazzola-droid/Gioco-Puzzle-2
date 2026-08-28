import Testing
@testable import PuzzleKit

struct PuzzleEngineTests {

    /// Draws a colour end to end, the way a player's finger would.
    @discardableResult
    private func draw(_ engine: inout PuzzleEngine, _ path: [Coordinate]) -> Bool {
        if let color = engine.blueprint.endpointColor(at: path[0]) {
            for rotor in engine.blueprint.fluxRotors where rotor.color == color {
                while !engine.isRotorAligned(at: rotor.coordinate) {
                    _ = engine.rotateRotor(at: rotor.coordinate)
                }
            }
        }
        guard engine.beginDrag(at: path[0]) else { return false }
        for cell in path.dropFirst() {
            guard engine.extendDrag(to: cell) else {
                engine.endDrag()
                return false
            }
        }
        engine.endDrag()
        return true
    }

    private func solved(level: Int, track: LevelTrack = .free) -> PuzzleEngine {
        var engine = PuzzleEngine(blueprint: LevelGenerator.generate(level: level, track: track))
        for path in engine.blueprint.solution { draw(&engine, path) }
        return engine
    }

    @Test("a fresh board is empty and unsolved")
    func startsEmpty() {
        let engine = PuzzleEngine(blueprint: LevelGenerator.generate(level: 1, track: .free))
        #expect(!engine.isSolved)
        #expect(engine.filledCells == 0)
        #expect(engine.moves == 0)
        #expect(engine.connectedColors == 0)
        #expect(engine.completionRatio == 0)
    }

    @Test("drawing the intended solution wins in exactly par moves", arguments: [1, 8, 25, 60])
    func solvingWorks(level: Int) {
        let engine = solved(level: level)
        #expect(engine.isSolved)
        #expect(engine.moves == engine.parMoves)
        #expect(engine.connectedColors == engine.colorCount)
        #expect(engine.filledCells == engine.blueprint.playableCells)
        #expect(engine.completionRatio == 1)
        #expect(engine.hintsUsed == 0)
    }

    @Test("a drag can only start on an endpoint or an existing trail")
    func dragStartRules() {
        let blueprint = LevelGenerator.generate(level: 12, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)
        let endpoint = blueprint.solution[0][0]
        let grabbed = engine.beginDrag(at: endpoint)
        #expect(grabbed)
        engine.endDrag()

        // An empty, non-endpoint cell has nothing to grab.
        let interior = blueprint.solution.first { $0.count >= 3 }?[1]
        #expect(interior != nil, "expected at least one colour longer than two cells")
        if let interior {
            let grabbedInterior = engine.beginDrag(at: interior)
            #expect(!grabbedInterior)
        }
        // Off-board taps are ignored rather than crashing.
        let grabbed2 = engine.beginDrag(at: Coordinate(-1, 0))
        #expect(!grabbed2)
        let grabbed3 = engine.beginDrag(at: Coordinate(blueprint.width, 0))
        #expect(!grabbed3)
    }

    @Test("a trail only extends onto adjacent cells")
    func extendRequiresAdjacency() {
        let blueprint = LevelGenerator.generate(level: 20, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)
        let path = blueprint.solution[0]
        let grabbed = engine.beginDrag(at: path[0])
        #expect(grabbed)
        // Jumping two cells ahead is not a legal step.
        if path.count > 2 {
            let stepped = engine.extendDrag(to: path[2])
            #expect(!stepped)
        }
        let stepped2 = engine.extendDrag(to: path[1])
        #expect(stepped2)
        engine.endDrag()
    }

    @Test("dragging back over the previous cell rewinds one step")
    func backtrackingRewinds() {
        let blueprint = LevelGenerator.generate(level: 30, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)
        let path = blueprint.solution.first { $0.count >= 4 } ?? blueprint.solution[0]

        let grabbed = engine.beginDrag(at: path[0])
        #expect(grabbed)
        let stepped = engine.extendDrag(to: path[1])
        #expect(stepped)
        let stepped2 = engine.extendDrag(to: path[2])
        #expect(stepped2)
        #expect(engine.filledCells == 3)
        let stepped3 = engine.extendDrag(to: path[1])
        #expect(stepped3)
        #expect(engine.filledCells == 2)
        #expect(engine.color(at: path[2]) == nil)
        engine.endDrag()
    }

    @Test("a completed colour locks at its endpoint")
    func completedColorLocks() {
        let blueprint = LevelGenerator.generate(level: 15, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)
        let path = blueprint.solution[0]
        draw(&engine, path)
        #expect(engine.isConnected(color: 0))

        // S is a destination and cannot energise a circuit in reverse.
        let rejected = engine.beginDrag(at: path[path.count - 1])
        #expect(!rejected)
        #expect(engine.isConnected(color: 0))

        // Restarting from N remains the player's way to redraw the circuit.
        let grabbed = engine.beginDrag(at: path[0])
        #expect(grabbed)
        engine.endDrag()
        #expect(!engine.isConnected(color: 0))
    }

    @Test("cutting through another colour truncates it")
    func cuttingTruncatesTheVictim() {
        let blueprint = LevelGenerator.generate(level: 40, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)

        // Lay down every colour, then re-lay the first one: the colours it
        // crosses must give way rather than blocking it.
        for path in blueprint.solution { draw(&engine, path) }
        #expect(engine.isSolved)

        let victim = blueprint.solution[1]
        engine.beginDrag(at: victim[0])
        engine.endDrag()
        #expect(!engine.isSolved)
        #expect(engine.filledCells < blueprint.playableCells)

        draw(&engine, victim)
        #expect(engine.isSolved)
    }

    @Test("another colour's endpoint is never passable")
    func endpointsBlockOtherColors() {
        // The fixture puts colour 0's endpoint at (0,0) directly beside colour
        // 1's endpoint at (1,0), so the rule is exercised exactly, not by luck.
        var engine = PuzzleEngine(blueprint: TestBoards.trio)
        let grabbed = engine.beginDrag(at: Coordinate(0, 0))
        #expect(grabbed)
        let stepped = engine.extendDrag(to: Coordinate(1, 0))
        #expect(!stepped)
        // The legal step below it still works.
        let stepped2 = engine.extendDrag(to: Coordinate(0, 1))
        #expect(stepped2)
        engine.endDrag()
    }

    @Test("walls block both grabbing and crossing")
    func wallsAreImpassableOnTheFixture() {
        var engine = PuzzleEngine(blueprint: TestBoards.walled)
        let grabbed = engine.beginDrag(at: Coordinate(1, 1))
        #expect(!grabbed)
        let grabbed2 = engine.beginDrag(at: Coordinate(1, 0))
        #expect(grabbed2)
        let stepped = engine.extendDrag(to: Coordinate(1, 1))
        #expect(!stepped)
        engine.endDrag()
    }

    @Test("reset clears the board and the move counter")
    func resetClearsEverything() {
        var engine = solved(level: 18)
        #expect(engine.isSolved)
        engine.reset()
        #expect(!engine.isSolved)
        #expect(engine.filledCells == 0)
        #expect(engine.moves == 0)
        #expect(engine.hintsUsed == 0)
    }

    @Test("a hint completes one colour and is counted")
    func hintCompletesOneColor() {
        let blueprint = LevelGenerator.generate(level: 33, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)
        let revealed = engine.revealHint()
        #expect(revealed != nil)
        #expect(engine.hintsUsed == 1)
        if let revealed {
            #expect(engine.isConnected(color: revealed))
            #expect(engine.paths[revealed] == blueprint.solution[revealed])
        }
    }

    @Test("revealing the solution wins the board from any state")
    func revealSolutionSolves() {
        let blueprint = LevelGenerator.generate(level: 45, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)
        // Scribble first, so the reveal has to clear conflicting trails.
        engine.beginDrag(at: blueprint.solution[0][0])
        engine.extendDrag(to: blueprint.solution[0][1])
        engine.endDrag()

        engine.revealSolution()
        #expect(engine.isSolved)
    }

    @Test("walls are never drawable", arguments: [70, 95])
    func wallsAreNotDrawable(level: Int) {
        let blueprint = LevelGenerator.generate(level: level, track: .pro)
        guard let wall = blueprint.blocked.min() else { return }
        var engine = PuzzleEngine(blueprint: blueprint)
        let grabbed = engine.beginDrag(at: wall)
        #expect(!grabbed)

        if let approach = wall.neighbours(width: blueprint.width, height: blueprint.height)
            .first(where: { blueprint.polarity(at: $0) == .north }) {
            let grabbed2 = engine.beginDrag(at: approach)
            #expect(grabbed2)
            let stepped = engine.extendDrag(to: wall)
            #expect(!stepped)
            engine.endDrag()
        }
    }

    @Test("clearing a colour frees its cells")
    func clearingAColorFreesCells() {
        let blueprint = LevelGenerator.generate(level: 16, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)
        draw(&engine, blueprint.solution[0])
        let filled = engine.filledCells
        #expect(filled > 0)
        engine.clear(color: 0)
        #expect(engine.filledCells == 0)
        #expect(!engine.isConnected(color: 0))
        // Clearing an already empty colour is a no-op, not a wasted move.
        let moves = engine.moves
        engine.clear(color: 0)
        #expect(engine.moves == moves)
    }

    @Test("a circuit can only start at its N pole")
    func polarityGivesCircuitsDirection() {
        let blueprint = LevelGenerator.generate(level: 1, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)
        let endpoints = blueprint.endpoints[0]

        #expect(blueprint.polarity(at: endpoints.start) == .north)
        #expect(blueprint.polarity(at: endpoints.end) == .south)
        let startedAtSouth = engine.beginDrag(at: endpoints.end)
        #expect(!startedAtSouth)
        let startedAtNorth = engine.beginDrag(at: endpoints.start)
        #expect(startedAtNorth)
    }

    @Test("an energised rotor locks in place")
    func occupiedRotorCannotRotate() {
        let blueprint = LevelGenerator.generate(level: 1, track: .free)
        var engine = PuzzleEngine(blueprint: blueprint)
        guard let rotor = blueprint.fluxRotors.first else {
            Issue.record("expected the introductory board to contain a rotor")
            return
        }

        let drewCircuit = draw(&engine, blueprint.solution[rotor.color])
        #expect(drewCircuit)
        let orientation = engine.rotorOrientation(at: rotor.coordinate)
        let moves = engine.moves

        let rotated = engine.rotateRotor(at: rotor.coordinate)
        #expect(!rotated)
        #expect(engine.rotorOrientation(at: rotor.coordinate) == orientation)
        #expect(engine.moves == moves)
    }

    @Test("misaligned rotors physically block the intended circuit")
    func rotorsGateTraversal() {
        let blueprint = LevelGenerator.generate(level: 25, track: .free)
        #expect(!blueprint.fluxRotors.isEmpty)
        var engine = PuzzleEngine(blueprint: blueprint)
        let rotor = blueprint.fluxRotors[0]
        let path = blueprint.solution[rotor.color]

        let started = engine.beginDrag(at: path[0])
        #expect(started)
        var reachedSouth = true
        for cell in path.dropFirst() {
            if !engine.extendDrag(to: cell) {
                reachedSouth = false
                break
            }
        }
        #expect(!reachedSouth)
    }

    @Test("rotating every field element to target enables a perfect solve")
    func alignedFieldSolvesAtPar() {
        var engine = PuzzleEngine(blueprint: LevelGenerator.generate(level: 48, track: .pro))
        for path in engine.blueprint.solution {
            let drewCircuit = draw(&engine, path)
            #expect(drewCircuit)
        }

        #expect(engine.alignedRotors == engine.totalRotors)
        #expect(engine.fieldStability == 1)
        #expect(engine.isSolved)
        #expect(engine.moves == engine.parMoves)
    }
}
