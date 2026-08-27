import SwiftUI
import PuzzleKit

/// The first thing every launch shows: a small board solving itself.
///
/// A splash on a casual game is either a signature or a toll. This one is
/// built so it can only be the first. It never gates anything - startup runs
/// underneath it - a tap dismisses it immediately, and it is over in about a
/// second and a half, which is roughly how long the home screen takes to feel
/// settled anyway.
///
/// What it draws is the game's own rule, not decoration borrowed from
/// somewhere else: flows growing from endpoint to endpoint, filling the grid,
/// never crossing. In the player's own equipped palette, so a subscriber's
/// launch looks like their game.
struct SplashView: View {

    // MARK: - Geometry

    /// Six by nine is roughly a phone's proportions, so the board fills the
    /// screen without letterboxing at either end.
    static let columns = 6
    static let rows = 9

    /// Hand-authored, not generated. A splash that is occasionally ugly is
    /// worse than one that is always the same, and this is the one screen with
    /// no gameplay reason to vary. The six flows tile the grid exactly and
    /// never touch - `SplashFlowTests` holds them to it.
    static let flows: [[GridPoint]] = [
        [(0, 0), (0, 1), (0, 2), (1, 2), (1, 1), (1, 0), (2, 0), (2, 1), (2, 2)],
        [(3, 0), (3, 1), (3, 2), (4, 2), (4, 1), (4, 0), (5, 0), (5, 1), (5, 2)],
        [(0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (5, 4), (4, 4), (3, 4)],
        [(2, 4), (1, 4), (0, 4), (0, 5), (1, 5), (2, 5), (3, 5), (4, 5), (5, 5)],
        [(0, 6), (0, 7), (0, 8), (1, 8), (1, 7), (1, 6), (2, 6), (2, 7), (2, 8)],
        [(3, 6), (3, 7), (3, 8), (4, 8), (4, 7), (4, 6), (5, 6), (5, 7), (5, 8)],
    ].map { $0.map(GridPoint.init) }

    struct GridPoint: Hashable {
        let column: Int
        let row: Int
        init(_ pair: (Int, Int)) { (column, row) = pair }
    }

    // MARK: - Timing

    /// One place for every moment, so the sequence can be read without running
    /// it. Seconds from the first frame.
    private enum Beat {
        static let nodesIn = 0.22
        static let flowsStart = 0.12
        static let flowStagger = 0.06
        static let flowGrowth = 0.50
        static let wordmarkIn = 0.55
        static let wordmarkDuration = 0.30
        static let shimmerStart = 0.85
        static let shimmerDuration = 0.55
        static let total = 1.55
        /// With motion reduced there is nothing to watch, so the screen only
        /// has to be long enough not to flash.
        static let stillTotal = 0.70
    }

    // MARK: - State

    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    let onFinish: () -> Void

    @State private var start = Date.now
    @State private var isFinished = false

    private var isStill: Bool {
        systemReduceMotion || services.profile.settings.reduceMotion
    }

    private var duration: Double {
        isStill ? Beat.stillTotal : Beat.total
    }

    var body: some View {
        TimelineView(.animation(paused: isStill)) { timeline in
            let elapsed = isStill ? Beat.total : timeline.date.timeIntervalSince(start)
            let theme = services.theme
            ZStack {
                ground
                Canvas { context, size in
                    draw(in: &context, size: size, elapsed: elapsed, theme: theme)
                }
                .allowsHitTesting(false)
                wordmark(elapsed: elapsed)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement()
        .accessibilityLabel(Text("app.name"))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("splash.skipHint"))
        .accessibilityAction { finish() }
        .task {
            // The sleep is the whole scheduler: nothing else is waited on, so
            // a slow store or a signed-out Game Center cannot hold the player
            // on this screen.
            try? await Task.sleep(for: .seconds(duration))
            finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        onFinish()
    }

    // MARK: - Ground

    /// Opens on exactly the colour of the static launch screen, so the handoff
    /// from the system's launch image to this view has nothing to see.
    private var ground: some View {
        LinearGradient(
            colors: [Color(hex: "#151A24"), Color(hex: "#1B2942"), Color(hex: "#141C2C")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Board

    private func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        elapsed: Double,
        theme: GameTheme
    ) {
        let board = boardRect(in: size)
        let cell = board.width / CGFloat(Self.columns)

        for (index, flow) in Self.flows.enumerated() {
            let grown = growth(of: index, at: elapsed)
            let color = theme.color(for: index)
            let points = flow.map { center(of: $0, in: board, cell: cell) }

            drawNode(&context, at: points[0], cell: cell, color: color,
                     scale: pop(elapsed, from: Double(index) * 0.03, over: Beat.nodesIn))
            drawNode(&context, at: points[points.count - 1], cell: cell, color: color,
                     scale: pop(elapsed, from: Double(index) * 0.03, over: Beat.nodesIn))

            guard grown > 0 else { continue }
            let path = trail(through: points, fraction: grown)
            // Halo first, line over it: the order is what makes the glow read
            // as light behind the flow rather than a fat outline around it.
            context.stroke(
                path,
                with: .color(color.opacity(0.30)),
                style: StrokeStyle(lineWidth: cell * 0.62, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: cell * 0.30, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawNode(
        _ context: inout GraphicsContext,
        at point: CGPoint,
        cell: CGFloat,
        color: Color,
        scale: Double
    ) {
        guard scale > 0 else { return }
        let radius = cell * 0.24 * scale
        let box = CGRect(
            x: point.x - radius, y: point.y - radius,
            width: radius * 2, height: radius * 2
        )
        context.fill(Path(ellipseIn: box.insetBy(dx: -radius * 0.7, dy: -radius * 0.7)),
                     with: .color(color.opacity(0.22)))
        context.fill(Path(ellipseIn: box), with: .color(color))
    }

    /// The board, centred and inset so the wordmark has room to sit on top of
    /// it without landing on a node.
    private func boardRect(in size: CGSize) -> CGRect {
        let cell = min(
            size.width * 0.82 / CGFloat(Self.columns),
            size.height * 0.72 / CGFloat(Self.rows)
        )
        let width = cell * CGFloat(Self.columns)
        let height = cell * CGFloat(Self.rows)
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func center(of point: GridPoint, in board: CGRect, cell: CGFloat) -> CGPoint {
        CGPoint(
            x: board.minX + (CGFloat(point.column) + 0.5) * cell,
            y: board.minY + (CGFloat(point.row) + 0.5) * cell
        )
    }

    /// The polyline truncated part-way along, so a flow appears to travel
    /// rather than fade in whole.
    private func trail(through points: [CGPoint], fraction: Double) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        let segments = Double(points.count - 1)
        let travelled = fraction * segments
        for index in 1..<points.count {
            let remaining = travelled - Double(index - 1)
            if remaining >= 1 {
                path.addLine(to: points[index])
            } else if remaining > 0 {
                let from = points[index - 1]
                let to = points[index]
                path.addLine(to: CGPoint(
                    x: from.x + (to.x - from.x) * remaining,
                    y: from.y + (to.y - from.y) * remaining
                ))
                break
            } else {
                break
            }
        }
        return path
    }

    // MARK: - Wordmark

    private func wordmark(elapsed: Double) -> some View {
        let appearance = pop(elapsed, from: Beat.wordmarkIn, over: Beat.wordmarkDuration)
        return VStack(spacing: 8) {
            Text("app.name")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(sheen(elapsed: elapsed))
                .shadow(color: .black.opacity(0.55), radius: 12, y: 4)
            Text("splash.tagline")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Ink.secondary)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 2)
        }
        .padding(.horizontal, 24)
        .multilineTextAlignment(.center)
        .padding(.vertical, 18)
        .background(
            // Just enough darkening to keep the words legible over whichever
            // colours the player has equipped underneath.
            RadialGradient(
                colors: [.black.opacity(0.62), .clear],
                center: .center, startRadius: 0, endRadius: 210
            )
        )
        .opacity(appearance)
        .scaleEffect(0.94 + 0.06 * appearance)
    }

    /// A highlight travelling left to right through the letters. Cheaper and
    /// steadier than masking a second copy of the text, and it degrades to a
    /// flat colour when the highlight is off the ends.
    private func sheen(elapsed: Double) -> LinearGradient {
        let travel = isStill
            ? 2.0
            : -0.25 + 1.5 * ease(progress(elapsed, from: Beat.shimmerStart, over: Beat.shimmerDuration))
        let stops = [
            Gradient.Stop(color: Ink.primary, location: clamp(travel - 0.16)),
            Gradient.Stop(color: .white, location: clamp(travel)),
            Gradient.Stop(color: Ink.primary, location: clamp(travel + 0.16)),
        ]
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Curves

    private func growth(of index: Int, at elapsed: Double) -> Double {
        let begins = Beat.flowsStart + Double(index) * Beat.flowStagger
        return ease(progress(elapsed, from: begins, over: Beat.flowGrowth))
    }

    private func pop(_ elapsed: Double, from begins: Double, over span: Double) -> Double {
        ease(progress(elapsed, from: begins, over: span))
    }

    private func progress(_ elapsed: Double, from begins: Double, over span: Double) -> Double {
        guard span > 0 else { return elapsed >= begins ? 1 : 0 }
        return clamp((elapsed - begins) / span)
    }

    /// Smoothstep. Linear growth reads as mechanical; this reads as drawn.
    private func ease(_ value: Double) -> Double {
        let t = clamp(value)
        return t * t * (3 - 2 * t)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
