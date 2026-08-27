import SwiftUI

/// The animated backdrop behind every screen.
///
/// Motion is opt-out: the decoration honours both the player's in-app
/// "reduce motion" setting and the system accessibility setting, because a
/// drifting background is exactly the kind of thing that makes some people
/// motion sick.
struct BackdropView: View {

    let style: GameTheme.BackgroundStyle
    var reduceMotionPreference = false

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var isStill: Bool {
        !style.isAnimated || reduceMotionPreference || systemReduceMotion
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: isStill ? nil : 1.0 / 30.0, paused: isStill)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .background(
            LinearGradient(
                colors: style.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .ignoresSafeArea()
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let phase = isStill ? 0 : time
        switch style {
        case .slate:
            return
        case .mesh:
            drawGrid(in: &context, size: size)
        case .drift:
            drawBlobs(in: &context, size: size, phase: phase, count: 5, tint: Color(hex: "#7A3BFF"))
        case .liquid:
            drawBlobs(in: &context, size: size, phase: phase, count: 4, tint: Color(hex: "#12C9AE"))
        case .starfield:
            drawStars(in: &context, size: size, phase: phase)
        }
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        let step: CGFloat = 44
        var path = Path()
        var x: CGFloat = 0
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }
        var y: CGFloat = 0
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += step
        }
        context.stroke(path, with: .color(.white.opacity(0.045)), lineWidth: 1)
    }

    private func drawBlobs(
        in context: inout GraphicsContext,
        size: CGSize,
        phase: TimeInterval,
        count: Int,
        tint: Color
    ) {
        context.addFilter(.blur(radius: 60))
        for index in 0..<count {
            let seed = Double(index) * 1.7
            let drift = phase * 0.08
            let x = (0.5 + 0.42 * sin(drift + seed)) * size.width
            let y = (0.5 + 0.38 * cos(drift * 1.3 + seed * 0.7)) * size.height
            let radius = size.width * (0.16 + 0.05 * Double(index % 3))
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.28)))
        }
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize, phase: TimeInterval) {
        // A fixed lattice with a slow twinkle: cheap, and it never reflows.
        let columns = 18
        let rows = 32
        for row in 0..<rows {
            for column in 0..<columns {
                let mixed = ((row &* 73_856_093) ^ (column &* 19_349_663)) & 0xFFFF
                let hash = Double(mixed) / 65_535.0
                guard hash > 0.72 else { continue }
                let x = (Double(column) + 0.5 + hash * 0.4) / Double(columns) * size.width
                let y = (Double(row) + 0.5 + hash * 0.4) / Double(rows) * size.height
                let twinkle = 0.35 + 0.4 * abs(sin(phase * 0.6 + hash * 12))
                let radius = 0.7 + hash * 1.1
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(twinkle * 0.6)))
            }
        }
    }
}
