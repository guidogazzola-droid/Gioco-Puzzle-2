import Testing
@testable import PuzzleKit

struct CubePuzzleEngineTests {
    private func cell(_ x: Int, _ y: Int) -> CubeCell {
        CubeCell(face: .front, x: x, y: y)
    }

    /// Only the front face contains the certificate paths; the right face is
    /// deliberately left unused so completion can prove that coverage is not
    /// a win condition.
    private func sparseBoard() -> CubeLevelBlueprint {
        CubeLevelBlueprint(
            level: 1,
            track: .free,
            side: 3,
            activeFaces: [.front, .right],
            blocked: [],
            solution: [
                [cell(0, 0), cell(1, 0), cell(2, 0)],
                [cell(0, 1), cell(1, 1), cell(2, 1)],
                [cell(0, 2), cell(1, 2), cell(2, 2)]
            ],
            seed: 1
        )
    }

    @discardableResult
    private func draw(_ engine: inout CubePuzzleEngine, path: [CubeCell]) -> Bool {
        guard let color = engine.blueprint.endpointColor(at: path[0]) else { return false }
        for rotor in engine.blueprint.fluxRotors where rotor.color == color {
            while !engine.isRotorAligned(at: rotor.cell) {
                _ = engine.rotateRotor(at: rotor.cell)
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

    @Test("the generated solution wins around cube edges", arguments: [1, 12, 40, 80, 91])
    func solvesAtPar(level: Int) {
        var engine = CubePuzzleEngine(
            blueprint: CubeLevelGenerator.generate(level: level, track: .free)
        )
        for path in engine.blueprint.solution {
            let didDraw = draw(&engine, path: path)
            #expect(didDraw)
        }
        #expect(engine.isSolved)
        #expect(engine.moves == engine.parMoves)
        #expect(engine.completionRatio == 1)
        #expect(engine.connectedColors == engine.colorCount)
    }

    @Test("a trail can cross a folded seam without teleporting")
    func seamTraversal() {
        let board = CubeLevelGenerator.generate(level: 40, track: .free)
        guard let path = board.solution.first(where: { path in
            zip(path, path.dropFirst()).contains { $0.0.face != $0.1.face }
        }) else {
            Issue.record("expected a circuit that crosses a seam")
            return
        }
        var engine = CubePuzzleEngine(blueprint: board)
        let didDraw = draw(&engine, path: path)
        #expect(didDraw)
        #expect(engine.isConnected(color: board.endpointColor(at: path[0])!))
    }

    @Test("either matching endpoint can start a circuit")
    func endpointsAreInterchangeable() {
        let board = CubeLevelGenerator.generate(level: 1, track: .free)
        var engine = CubePuzzleEngine(blueprint: board)
        let reverse = Array(board.solution[0].reversed())
        #expect(draw(&engine, path: reverse))
        #expect(engine.isConnected(color: 0))
    }

    @Test("connecting every pair wins while surface tiles remain empty")
    func coverageIsNotRequired() {
        var engine = CubePuzzleEngine(blueprint: sparseBoard())
        for path in engine.blueprint.solution {
            #expect(draw(&engine, path: path))
        }
        #expect(engine.isSolved)
        #expect(engine.connectedColors == engine.colorCount)
        #expect(engine.filledCells < engine.blueprint.playableCells)
        #expect(engine.completionRatio == 1)
    }

    @Test("a filament cannot cross or erase another filament")
    func crossingIsRejected() {
        var engine = CubePuzzleEngine(blueprint: sparseBoard())
        let middlePath = engine.blueprint.solution[1]
        #expect(draw(&engine, path: middlePath))
        let protectedPath = engine.paths[1]

        #expect(engine.beginDrag(at: cell(0, 0)))
        #expect(engine.extendDrag(to: cell(1, 0)))
        #expect(!engine.extendDrag(to: cell(1, 1)))
        engine.endDrag()

        #expect(engine.paths[1] == protectedPath)
        #expect(engine.color(at: cell(1, 1)) == 1)
    }

    @Test("misaligned cube rotors block current")
    func rotorsGateTrails() {
        let board = CubeLevelGenerator.generate(level: 91, track: .free)
        #expect(!board.fluxRotors.isEmpty)
        guard let rotor = board.fluxRotors.first else { return }
        let path = board.solution[rotor.color]
        var engine = CubePuzzleEngine(blueprint: board)
        let started = engine.beginDrag(at: path[0])
        #expect(started)
        var reachedEnd = true
        for cell in path.dropFirst() {
            if !engine.extendDrag(to: cell) {
                reachedEnd = false
                break
            }
        }
        engine.endDrag()
        #expect(!reachedEnd)
    }

    @Test("hints and reset preserve cube invariants")
    func hintAndReset() {
        let board = CubeLevelGenerator.generate(level: 55, track: .pro)
        var engine = CubePuzzleEngine(blueprint: board)
        let color = engine.revealHint()
        #expect(color != nil)
        if let color { #expect(engine.paths[color] == board.solution[color]) }
        #expect(engine.hintsUsed == 1)
        engine.reset()
        #expect(engine.filledCells == 0)
        #expect(engine.moves == 0)
        #expect(engine.hintsUsed == 0)
    }

    @Test("rotating the cube mid-circuit does not make par unreachable")
    func looseEndResumesWithoutAnotherMove() {
        let board = CubeLevelGenerator.generate(level: 40, track: .free)
        guard let path = board.solution.first(where: { $0.count >= 4 }) else {
            Issue.record("expected a circuit long enough to pause")
            return
        }
        var engine = CubePuzzleEngine(blueprint: board)
        let color = board.endpointColor(at: path[0])!
        for rotor in board.fluxRotors where rotor.color == color {
            while !engine.isRotorAligned(at: rotor.cell) {
                _ = engine.rotateRotor(at: rotor.cell)
            }
        }

        let started = engine.beginDrag(at: path[0])
        #expect(started)
        let firstStep = engine.extendDrag(to: path[1])
        #expect(firstStep)
        engine.endDrag()
        let movesAfterFirstRun = engine.moves

        let resumed = engine.beginDrag(at: path[1])
        #expect(resumed)
        for cell in path.dropFirst(2) { _ = engine.extendDrag(to: cell) }
        engine.endDrag()
        #expect(engine.moves == movesAfterFirstRun)
        #expect(engine.isConnected(color: color))
    }
}
