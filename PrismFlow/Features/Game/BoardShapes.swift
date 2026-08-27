import SwiftUI

/// Endpoint marker shapes, one per `nodeShape` cosmetic.
enum BoardShapes {

    static func path(for node: GameTheme.NodeShape, center: CGPoint, radius: CGFloat) -> Path {
        switch node {
        case .dot:
            Path(ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
        case .hex:
            polygon(sides: 6, center: center, radius: radius, rotation: .pi / 6)
        case .gem:
            polygon(sides: 4, center: center, radius: radius * 1.12, rotation: 0)
        case .bloom:
            bloom(center: center, radius: radius)
        }
    }

    static func polygon(sides: Int, center: CGPoint, radius: CGFloat, rotation: CGFloat) -> Path {
        var path = Path()
        guard sides >= 3 else { return path }
        for index in 0..<sides {
            let angle = rotation - .pi / 2 + (CGFloat(index) * 2 * .pi / CGFloat(sides))
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// Six overlapping lobes around a core - reads as a flower at endpoint size.
    static func bloom(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let lobe = radius * 0.55
        let offset = radius * 0.52
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            let lobeCenter = CGPoint(
                x: center.x + cos(angle) * offset,
                y: center.y + sin(angle) * offset
            )
            path.addEllipse(in: CGRect(
                x: lobeCenter.x - lobe, y: lobeCenter.y - lobe,
                width: lobe * 2, height: lobe * 2
            ))
        }
        path.addEllipse(in: CGRect(
            x: center.x - radius * 0.5, y: center.y - radius * 0.5,
            width: radius, height: radius
        ))
        return path
    }
}
