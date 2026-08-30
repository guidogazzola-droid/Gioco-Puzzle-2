import SwiftUI
import PuzzleKit

/// First-launch tutorial.
///
/// Three screens, skippable, and no monetisation anywhere on them: the first
/// session has to sell the game, not the store.
struct OnboardingView: View {

    @Environment(AppServices.self) private var services

    @State private var page = 0

    private let pages: [(icon: String, titleKey: LocalizedStringKey, bodyKey: LocalizedStringKey)] = [
        ("cube.transparent", "onboarding.1.title", "onboarding.1.body"),
        ("arrow.clockwise.circle.fill", "onboarding.2.title", "onboarding.2.body"),
        ("rotate.3d", "onboarding.3.title", "onboarding.3.body")
    ]

    var body: some View {
        ZStack {
            BackdropView(style: .slate)

            VStack(spacing: 24) {
                Spacer(minLength: 12)

                DemoCubeView()
                    .frame(maxWidth: 320, maxHeight: 320)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        VStack(spacing: 12) {
                            Image(systemName: pages[index].icon)
                                .font(.system(size: 30))
                                .foregroundStyle(Ink.accent)
                            Text(pages[index].titleKey)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Ink.primary)
                            Text(pages[index].bodyKey)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Ink.secondary)
                                .padding(.horizontal, 32)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 190)

                VStack(spacing: 10) {
                    Button {
                        if page < pages.count - 1 {
                            withAnimation { page += 1 }
                        } else {
                            services.completeOnboarding()
                        }
                    } label: {
                        Text(page < pages.count - 1 ? nextKey : startKey)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        services.completeOnboarding()
                    } label: {
                        Text("onboarding.skip")
                            .font(.subheadline)
                            .foregroundStyle(Ink.secondary)
                    }
                    .opacity(page < pages.count - 1 ? 1 : 0)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }

    private var nextKey: LocalizedStringKey { "onboarding.next" }
    private var startKey: LocalizedStringKey { "onboarding.start" }
}

/// A small board that draws itself, used to show the mechanic rather than
/// describe it.
private struct DemoCubeView: View {

    /// Generated once: the tutorial board never changes, and re-running the
    /// generator on every layout pass would be waste.
    private static let blueprint = CubeLevelGenerator.generate(level: 5, track: .free)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            CubeBoardView(
                engine: engine(at: phase),
                theme: .preview,
                isInteractive: false
            )
        }
    }

    /// Replays the intended solution on a loop by feeding the engine the same
    /// moves a player would make.
    private func engine(at phase: TimeInterval) -> CubePuzzleEngine {
        let blueprint = Self.blueprint
        var engine = CubePuzzleEngine(blueprint: blueprint)
        for rotor in blueprint.fluxRotors {
            while !engine.isRotorAligned(at: rotor.cell) {
                _ = engine.rotateRotor(at: rotor.cell)
            }
        }
        let totalCells = blueprint.solution.reduce(0) { $0 + $1.count }
        let cycle = Double(totalCells) + 6
        let progress = phase.truncatingRemainder(dividingBy: cycle * 0.35) / 0.35
        var drawn = 0

        for path in blueprint.solution {
            guard drawn < Int(progress) else { break }
            engine.beginDrag(at: path[0])
            for cell in path.dropFirst() {
                guard drawn < Int(progress) else { break }
                engine.extendDrag(to: cell)
                drawn += 1
            }
            engine.endDrag()
            drawn += 1
        }
        return engine
    }
}
