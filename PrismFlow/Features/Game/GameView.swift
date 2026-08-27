import SwiftUI
import PuzzleKit

/// The board screen: HUD, puzzle, and the completion flow.
struct GameView: View {

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: GameViewModel
    @State private var isShowingPaywall = false

    init(model: GameViewModel) {
        _model = State(initialValue: model)
    }

    private var theme: GameTheme { services.theme }

    var body: some View {
        ZStack {
            BackdropView(
                style: theme.background,
                reduceMotionPreference: services.profile.settings.reduceMotion
            )

            VStack(spacing: 0) {
                header
                Spacer(minLength: 8)
                board
                Spacer(minLength: 8)
                controls
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if model.isShowingCompletion, let result = model.result {
                LevelCompleteView(
                    result: result,
                    isDaily: model.mode.isDaily,
                    hasNextLevel: model.nextLevel != nil,
                    onNext: { Task { await model.advance() } },
                    onReplay: { model.replay() },
                    onExit: { dismiss() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.isShowingCompletion)
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $model.isShowingHintOptions) {
            HintOptionsView(
                onWatchAd: { Task { await model.watchAdForHint() } },
                onBuyWithGems: { model.buyHintWithGems() },
                onSubscribe: { isShowingPaywall = true }
            )
            .presentationDetents([.height(380)])
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(context: .hints)
        }
        .onChange(of: scenePhase) { _, phase in
            // Never let backgrounded time count toward a best-time record.
            if phase == .active { model.resumeClock() } else { model.pauseClock() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Ink.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Ink.card))
            }
            .accessibilityLabel(Text("common.back"))

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.headline)
                    .foregroundStyle(Ink.primary)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(Ink.secondary)
            }

            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                CounterPill(
                    systemImage: "clock",
                    value: Self.timeString(model.elapsedSeconds),
                    tint: Ink.secondary
                )
            }
        }
        .padding(.top, 8)
    }

    private var titleText: String {
        if model.mode.isDaily {
            return NSLocalizedString("game.daily.title", comment: "")
        }
        let key = model.track == .pro ? "game.title.pro" : "game.title.free"
        return String(format: NSLocalizedString(key, comment: ""), model.level)
    }

    private var subtitleText: String {
        String(
            format: NSLocalizedString("game.subtitle", comment: ""),
            model.progressLabel, model.moves, model.par
        )
    }

    // MARK: - Board

    private var board: some View {
        BoardView(
            engine: model.engine,
            theme: theme,
            colorBlindAssist: services.profile.settings.colorBlindAssist,
            isInteractive: model.result == nil,
            onBegin: { model.begin(at: $0) },
            onExtend: { model.extend(to: $0) },
            onEnd: { model.endDrag() }
        )
        .padding(.vertical, 4)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            controlButton(
                icon: "arrow.counterclockwise",
                labelKey: "game.action.reset",
                action: { model.reset() }
            )

            controlButton(
                icon: "lightbulb.fill",
                labelKey: "game.action.hint",
                badge: hintBadge,
                tint: Ink.gold,
                action: { model.requestHint() }
            )

            if services.showsAds {
                controlButton(
                    icon: "crown.fill",
                    labelKey: "game.action.goPro",
                    tint: Ink.pro,
                    action: { isShowingPaywall = true }
                )
            } else {
                CounterPill(systemImage: "diamond.fill", value: "\(services.profile.gems)")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var hintBadge: String? {
        if services.entitlements.hasUnlimitedHints { return "∞" }
        return "\(services.profile.hints)"
    }

    private func controlButton(
        icon: String,
        labelKey: LocalizedStringKey,
        badge: String? = nil,
        tint: Color = Ink.accent,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 26)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Ink.primary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Ink.cardRaised))
                            .offset(x: 6, y: -6)
                    }
                }
                Text(labelKey)
                    .font(.caption2)
                    .foregroundStyle(Ink.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.card))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Ink.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    static func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
