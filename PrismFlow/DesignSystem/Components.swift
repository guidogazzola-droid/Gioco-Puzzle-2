import SwiftUI

/// The one primary button style in the app.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Ink.accent
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(isProminent ? Color(hex: "#0B1018") : Ink.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isProminent ? AnyShapeStyle(tint) : AnyShapeStyle(Ink.cardRaised))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isProminent ? .clear : Ink.stroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A compact, tappable pill used for the HUD counters.
struct CounterPill: View {
    let systemImage: String
    let value: String
    var tint: Color = Ink.gold

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Ink.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Ink.card))
        .overlay(Capsule().strokeBorder(Ink.stroke, lineWidth: 1))
    }
}

/// Star row used on the level map and the completion sheet.
struct StarRow: View {
    let stars: Int
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index < stars ? Ink.gold : Ink.stroke)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(String(format: NSLocalizedString("a11y.stars", comment: "Star rating"), stars))
        )
    }
}

/// Card container with the app's standard padding and border.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Ink.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Ink.stroke, lineWidth: 1)
            )
    }
}

/// A small badge marking Pro-only content.
struct ProBadge: View {
    var body: some View {
        Text("badge.pro", bundle: .main)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Ink.pro.opacity(0.22)))
            .overlay(Capsule().strokeBorder(Ink.pro.opacity(0.6), lineWidth: 1))
            .foregroundStyle(Ink.pro)
    }
}
