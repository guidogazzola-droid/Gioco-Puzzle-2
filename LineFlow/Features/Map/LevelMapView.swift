import SwiftUI
import PuzzleKit

/// Chapter-by-chapter level picker.
///
/// The campaign is endless, so the map is generated the same way the levels
/// are: chapters are computed from the player's progress rather than authored.
struct LevelMapView: View {

    @Environment(AppServices.self) private var services

    let track: LevelTrack

    @State private var selectedLevel: Int? = nil

    private var progress: TrackProgress { services.profile.progress(for: track) }

    private var chapters: [Chapter] {
        ChapterCatalog.chapters(track: track, reaching: progress.highestUnlocked)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        ZStack {
            BackdropView(
                style: services.theme.background,
                reduceMotionPreference: services.profile.settings.reduceMotion
            )
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
                    ForEach(chapters) { chapter in
                        chapterSection(chapter)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(Text(titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedLevel) { level in
            GameView(model: GameViewModel(
                mode: .campaign(track),
                level: level,
                services: services
            ))
        }
    }

    private var titleKey: LocalizedStringKey {
        track == .pro ? "map.title.pro" : "map.title.free"
    }

    private func chapterSection(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey(chapter.titleKey))
                    .font(.headline)
                    .foregroundStyle(Ink.primary)
                Spacer()
                Label(
                    "\(starCount(in: chapter))/\(chapter.maximumStars)",
                    systemImage: "star.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Ink.gold)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(chapter.range), id: \.self) { level in
                    levelTile(level)
                }
            }
        }
    }

    private func starCount(in chapter: Chapter) -> Int {
        chapter.range.reduce(0) { $0 + progress.stars(for: $1) }
    }

    private func levelTile(_ level: Int) -> some View {
        let unlocked = progress.isUnlocked(level)
        let stars = progress.stars(for: level)
        let isBoss = DifficultyCurve.isBoss(level: level)

        return Button {
            guard unlocked else { return }
            selectedLevel = level
        } label: {
            VStack(spacing: 4) {
                if unlocked {
                    Text("\(level)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Ink.primary)
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < stars ? "star.fill" : "star")
                                .font(.system(size: 7))
                                .foregroundStyle(index < stars ? Ink.gold : Ink.stroke)
                        }
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Ink.stroke)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(unlocked ? Ink.card : Ink.card.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isBoss && unlocked ? Ink.gold.opacity(0.7) : Ink.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(Text(accessibilityLabel(level: level, unlocked: unlocked, stars: stars)))
    }

    private func accessibilityLabel(level: Int, unlocked: Bool, stars: Int) -> String {
        guard unlocked else {
            return String(format: NSLocalizedString("a11y.levelLocked", comment: ""), level)
        }
        return String(format: NSLocalizedString("a11y.level", comment: ""), level, stars)
    }
}
