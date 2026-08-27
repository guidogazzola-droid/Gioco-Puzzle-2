import CoreGraphics
import PuzzleKit

/// Maps between the puzzle grid and the view's coordinate space.
///
/// Kept separate from the renderer so the hit-testing used by the drag gesture
/// and the geometry used by the drawing code can never drift apart.
struct BoardGeometry: Equatable {

    let columns: Int
    let rows: Int
    let cellSize: CGFloat
    let origin: CGPoint

    init(size: CGSize, columns: Int, rows: Int, inset: CGFloat = 6) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)

        let available = CGSize(
            width: max(0, size.width - inset * 2),
            height: max(0, size.height - inset * 2)
        )
        let cell = min(available.width / CGFloat(self.columns), available.height / CGFloat(self.rows))
        self.cellSize = max(1, cell)

        let boardSize = CGSize(
            width: self.cellSize * CGFloat(self.columns),
            height: self.cellSize * CGFloat(self.rows)
        )
        self.origin = CGPoint(
            x: (size.width - boardSize.width) / 2,
            y: (size.height - boardSize.height) / 2
        )
    }

    var boardRect: CGRect {
        CGRect(
            origin: origin,
            size: CGSize(width: cellSize * CGFloat(columns), height: cellSize * CGFloat(rows))
        )
    }

    func rect(for cell: Coordinate) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(cell.x) * cellSize,
            y: origin.y + CGFloat(cell.y) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    func center(of cell: Coordinate) -> CGPoint {
        CGPoint(
            x: origin.x + (CGFloat(cell.x) + 0.5) * cellSize,
            y: origin.y + (CGFloat(cell.y) + 0.5) * cellSize
        )
    }

    /// The cell under a touch, or `nil` if the touch is off the board.
    func coordinate(at point: CGPoint) -> Coordinate? {
        let x = Int(((point.x - origin.x) / cellSize).rounded(.down))
        let y = Int(((point.y - origin.y) / cellSize).rounded(.down))
        guard x >= 0, x < columns, y >= 0, y < rows else { return nil }
        return Coordinate(x, y)
    }

    /// Cells to walk through when a fast drag jumps more than one cell.
    ///
    /// Without this, sliding a finger quickly leaves gaps in the trail. The
    /// route turns at most once, along the axis the finger travelled furthest,
    /// which tracks the gesture closely enough that the trail never looks
    /// wrong.
    static func route(from start: Coordinate, to end: Coordinate) -> [Coordinate] {
        guard start != end else { return [] }
        var cells: [Coordinate] = []
        let stepX = end.x > start.x ? 1 : -1
        let stepY = end.y > start.y ? 1 : -1

        if abs(end.x - start.x) >= abs(end.y - start.y) {
            var x = start.x
            while x != end.x { x += stepX; cells.append(Coordinate(x, start.y)) }
            var y = start.y
            while y != end.y { y += stepY; cells.append(Coordinate(end.x, y)) }
        } else {
            var y = start.y
            while y != end.y { y += stepY; cells.append(Coordinate(start.x, y)) }
            var x = start.x
            while x != end.x { x += stepX; cells.append(Coordinate(x, end.y)) }
        }
        return cells
    }
}
