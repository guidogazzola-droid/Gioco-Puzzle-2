import SwiftUI
import PuzzleKit

/// Draws the puzzle and turns finger movement into engine calls.
///
/// Everything is drawn in a single `Canvas` pass rather than as a grid of
/// views: a 13x13 board is 169 cells plus trails, and one draw call keeps the
/// drag at 120 Hz on the devices that support it.
struct BoardView: View {

    let engine: PuzzleEngine
    let theme: GameTheme
    var colorBlindAssist = false
    var isInteractive = true

    /// Return `false` to reject the touch, so the gesture can retry.
    var onBegin: (Coordinate) -> Bool = { _ in false }
    var onExtend: (Coordinate) -> Bool = { _ in false }
    var onEnd: () -> Void = {}
    var onRotate: (Coordinate) -> Bool = { _ in false }

    @State private var isDragging = false
    @State private var lastCell: Coordinate? = nil

    private var blueprint: LevelBlueprint { engine.blueprint }

    var body: some View {
        GeometryReader { proxy in
            let geometry = BoardGeometry(
                size: proxy.size,
                columns: blueprint.width,
                rows: blueprint.height
            )
            Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
                draw(in: &context, geometry: geometry)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(geometry), including: isInteractive ? .all : .none)
            .simultaneousGesture(tapGesture(geometry), including: isInteractive ? .all : .none)
            .accessibilityElement()
            .accessibilityLabel(Text(accessibilityLabel))
        }
        .aspectRatio(CGFloat(blueprint.width) / CGFloat(blueprint.height), contentMode: .fit)
    }

    private var accessibilityLabel: String {
        String(
            format: NSLocalizedString("a11y.board", comment: "Board summary"),
            blueprint.width, blueprint.height, engine.connectedColors, engine.colorCount
        )
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, geometry: BoardGeometry) {
        drawCells(in: &context, geometry: geometry)
        drawMagneticFields(in: &context, geometry: geometry)
        drawTrails(in: &context, geometry: geometry)
        drawRotors(in: &context, geometry: geometry)
        drawEndpoints(in: &context, geometry: geometry)
    }

    private func drawMagneticFields(
        in context: inout GraphicsContext,
        geometry: BoardGeometry
    ) {
        for (index, endpoints) in blueprint.endpoints.enumerated() {
            let color = theme.color(for: index)
            for cell in [endpoints.start, endpoints.end] {
                let center = geometry.center(of: cell)
                for scale in [0.42, 0.54] {
                    let radius = geometry.cellSize * scale
                    let rect = CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(scale == 0.42 ? 0.15 : 0.07)),
                        lineWidth: max(0.8, geometry.cellSize * 0.018)
                    )
                }
            }
        }

        for rotor in blueprint.fluxRotors {
            let center = geometry.center(of: rotor.coordinate)
            let radius = geometry.cellSize * 0.45
            let rect = CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(theme.color(for: rotor.color).opacity(
                    engine.isRotorAligned(at: rotor.coordinate) ? 0.13 : 0.06
                ))
            )
        }
    }

    private func drawCells(in context: inout GraphicsContext, geometry: BoardGeometry) {
        let board = geometry.boardRect.insetBy(dx: -6, dy: -6)
        context.fill(
            Path(roundedRect: board, cornerRadius: geometry.cellSize * 0.35, style: .continuous),
            with: .color(.black.opacity(0.22))
        )

        let padding = geometry.cellSize * 0.06
        for y in 0..<geometry.rows {
            for x in 0..<geometry.columns {
                let cell = Coordinate(x, y)
                let rect = geometry.rect(for: cell).insetBy(dx: padding, dy: padding)
                let tile = Path(
                    roundedRect: rect,
                    cornerRadius: geometry.cellSize * 0.18,
                    style: .continuous
                )
                if blueprint.isBlocked(cell) {
                    // Walls read as solid mass, not as an empty cell.
                    context.fill(tile, with: .color(.black.opacity(0.55)))
                    context.stroke(tile, with: .color(.white.opacity(0.08)), lineWidth: 1)
                } else {
                    context.fill(tile, with: .color(.white.opacity(0.045)))
                }
            }
        }
    }

    private func drawTrails(in context: inout GraphicsContext, geometry: BoardGeometry) {
        let width = geometry.cellSize * theme.trail.thickness
        let glow = geometry.cellSize * theme.trail.glowRadius

        for (index, cells) in engine.paths.enumerated() where cells.count > 1 {
            let color = theme.color(for: index)
            var line = Path()
            line.move(to: geometry.center(of: cells[0]))
            for cell in cells.dropFirst() {
                line.addLine(to: geometry.center(of: cell))
            }

            if glow > 0 {
                context.stroke(
                    line,
                    with: .color(color.opacity(0.30)),
                    style: StrokeStyle(lineWidth: width + glow, lineCap: .round, lineJoin: .round)
                )
            }
            context.stroke(
                line,
                with: .color(color),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
            if theme.trail.drawsHighlight {
                context.stroke(
                    line,
                    with: .color(.white.opacity(0.30)),
                    style: StrokeStyle(lineWidth: width * 0.28, lineCap: .round, lineJoin: .round)
                )
            }

            // A cap on the loose end shows the player where their finger is.
            if !engine.isConnected(color: index), let head = cells.last {
                let radius = width * 0.62
                let rect = CGRect(
                    x: geometry.center(of: head).x - radius,
                    y: geometry.center(of: head).y - radius,
                    width: radius * 2, height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(color))
                context.stroke(
                    Path(ellipseIn: rect.insetBy(dx: -radius * 0.28, dy: -radius * 0.28)),
                    with: .color(color.opacity(0.45)),
                    lineWidth: max(1, geometry.cellSize * 0.04)
                )
            }
        }
    }

    private func drawEndpoints(in context: inout GraphicsContext, geometry: BoardGeometry) {
        let radius = geometry.cellSize * 0.27

        for (index, endpoints) in blueprint.endpoints.enumerated() {
            let color = theme.color(for: index)
            let connected = engine.isConnected(color: index)

            for cell in [endpoints.start, endpoints.end] {
                let center = geometry.center(of: cell)
                let shape = BoardShapes.path(
                    for: theme.node, center: center, radius: radius * 1.26
                )
                let coreRect = CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                )
                context.fill(
                    BoardShapes.path(for: theme.node, center: center, radius: radius * 1.48),
                    with: .color(color.opacity(0.24))
                )
                context.fill(shape, with: .color(.black.opacity(0.72)))
                context.stroke(
                    shape,
                    with: .color(color),
                    lineWidth: max(2, geometry.cellSize * 0.07)
                )
                context.fill(Path(ellipseIn: coreRect), with: .color(color))

                let glintRadius = radius * 0.18
                let glintRect = CGRect(
                    x: center.x - glintRadius, y: center.y - glintRadius,
                    width: glintRadius * 2, height: glintRadius * 2
                )
                context.fill(Path(ellipseIn: glintRect), with: .color(.white.opacity(0.92)))

                if connected {
                    context.stroke(
                        BoardShapes.path(for: theme.node, center: center, radius: radius * 1.58),
                        with: .color(.white.opacity(0.85)),
                        lineWidth: max(1.5, geometry.cellSize * 0.05)
                    )
                }

                if colorBlindAssist {
                    var text = context.resolve(
                        Text(theme.glyph(for: index))
                            .font(.system(
                                size: geometry.cellSize * 0.23,
                                weight: .black,
                                design: .rounded
                            ))
                    )
                    text.shading = .color(.black.opacity(0.82))
                    context.draw(text, at: center, anchor: .center)
                }
            }
        }
    }

    private func drawRotors(in context: inout GraphicsContext, geometry: BoardGeometry) {
        let radius = geometry.cellSize * 0.34

        for rotor in blueprint.fluxRotors {
            guard let orientation = engine.rotorOrientation(at: rotor.coordinate) else { continue }
            let center = geometry.center(of: rotor.coordinate)
            let color = theme.color(for: rotor.color)
            let rect = CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )
            let disc = Path(ellipseIn: rect)

            context.fill(disc, with: .color(.black.opacity(0.88)))
            context.stroke(
                disc,
                with: .color(color.opacity(0.95)),
                lineWidth: max(1.5, geometry.cellSize * 0.055)
            )

            for port in orientation.ports {
                var segment = Path()
                segment.move(to: center)
                segment.addLine(to: portPoint(
                    port, center: center, distance: geometry.cellSize * 0.34
                ))
                context.stroke(
                    segment,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: geometry.cellSize * 0.13,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }

            let hubRadius = geometry.cellSize * 0.09
            let hub = CGRect(
                x: center.x - hubRadius, y: center.y - hubRadius,
                width: hubRadius * 2, height: hubRadius * 2
            )
            context.fill(Path(ellipseIn: hub), with: .color(.white.opacity(0.92)))

            if engine.isRotorAligned(at: rotor.coordinate) {
                context.stroke(
                    Path(ellipseIn: rect.insetBy(dx: -geometry.cellSize * 0.055,
                                                 dy: -geometry.cellSize * 0.055)),
                    with: .color(.white.opacity(0.72)),
                    lineWidth: max(1, geometry.cellSize * 0.025)
                )
            }
        }
    }

    private func portPoint(
        _ direction: FieldDirection,
        center: CGPoint,
        distance: CGFloat
    ) -> CGPoint {
        switch direction {
        case .north: CGPoint(x: center.x, y: center.y - distance)
        case .east: CGPoint(x: center.x + distance, y: center.y)
        case .south: CGPoint(x: center.x, y: center.y + distance)
        case .west: CGPoint(x: center.x - distance, y: center.y)
        }
    }

    // MARK: - Gesture

    private func dragGesture(_ geometry: BoardGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let cell = geometry.coordinate(at: value.location) else { return }

                guard isDragging else {
                    // Keep retrying until the finger lands on something
                    // grabbable, so a slightly-off first touch still works.
                    if onBegin(cell) {
                        isDragging = true
                        lastCell = cell
                    }
                    return
                }

                guard let previous = lastCell, previous != cell else { return }
                var reached = previous
                for step in BoardGeometry.route(from: previous, to: cell) {
                    guard onExtend(step) else { break }
                    reached = step
                }
                lastCell = reached
            }
            .onEnded { _ in
                if isDragging { onEnd() }
                isDragging = false
                lastCell = nil
            }
    }

    private func tapGesture(_ geometry: BoardGeometry) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard let cell = geometry.coordinate(at: value.location) else { return }
                _ = onRotate(cell)
            }
    }
}
