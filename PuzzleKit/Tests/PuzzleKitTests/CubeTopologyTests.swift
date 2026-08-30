import Testing
@testable import PuzzleKit

struct CubeTopologyTests {
    @Test("every cube edge mapping is reversible", arguments: [3, 4, 5])
    func seamsAreReversible(side: Int) {
        for face in CubeFace.allCases {
            for y in 0..<side {
                for x in 0..<side {
                    let cell = CubeCell(face: face, x: x, y: y)
                    let neighbours = cell.neighbours(side: side)
                    #expect(neighbours.count == 4)
                    #expect(Set(neighbours).count == 4)
                    for neighbour in neighbours {
                        #expect(CubeTopology.areAdjacent(neighbour, cell, side: side))
                    }
                }
            }
        }
    }

    @Test("crossing each side folds onto the expected face")
    func knownFrontSeams() {
        let side = 3
        #expect(CubeCell(face: .front, x: 1, y: 0).neighbour(in: .north, side: side)?.face == .top)
        #expect(CubeCell(face: .front, x: 2, y: 1).neighbour(in: .east, side: side)?.face == .right)
        #expect(CubeCell(face: .front, x: 1, y: 2).neighbour(in: .south, side: side)?.face == .bottom)
        #expect(CubeCell(face: .front, x: 0, y: 1).neighbour(in: .west, side: side)?.face == .left)
    }
}
