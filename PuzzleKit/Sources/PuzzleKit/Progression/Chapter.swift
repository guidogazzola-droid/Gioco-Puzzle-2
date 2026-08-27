import Foundation

/// A run of levels presented as one themed chapter on the map screen.
///
/// Chapters are computed, not authored: the campaign is endless, so chapter
/// names and palettes cycle through a fixed list rather than being enumerated.
public struct Chapter: Identifiable, Hashable, Sendable {
    public let index: Int
    public let track: LevelTrack
    /// Localisation key, resolved by the app layer.
    public let titleKey: String
    public let paletteID: String
    public let range: ClosedRange<Int>

    public var id: String { "\(track.rawValue)-\(index)" }
    public var levelCount: Int { range.count }
    public var maximumStars: Int { range.count * 3 }
}

public enum ChapterCatalog {

    public static let levelsPerChapter = 30

    static let themes: [(titleKey: String, paletteID: String)] = [
        ("chapter.dawn", "aurora"),
        ("chapter.tide", "tide"),
        ("chapter.ember", "ember"),
        ("chapter.circuit", "circuit"),
        ("chapter.orchid", "orchid"),
        ("chapter.glacier", "glacier"),
        ("chapter.dusk", "dusk"),
        ("chapter.nebula", "nebula")
    ]

    public static func chapterIndex(containing level: Int) -> Int {
        max(0, (max(1, level) - 1) / levelsPerChapter)
    }

    public static func chapter(at index: Int, track: LevelTrack) -> Chapter {
        let index = max(0, index)
        let theme = themes[index % themes.count]
        let first = index * levelsPerChapter + 1
        return Chapter(
            index: index,
            track: track,
            titleKey: theme.titleKey,
            paletteID: theme.paletteID,
            range: first...(first + levelsPerChapter - 1)
        )
    }

    public static func chapter(containing level: Int, track: LevelTrack) -> Chapter {
        chapter(at: chapterIndex(containing: level), track: track)
    }

    /// Chapters to render on the map: everything reached so far plus one more
    /// to preview, so the list always shows somewhere left to go.
    public static func chapters(track: LevelTrack, reaching level: Int) -> [Chapter] {
        let last = chapterIndex(containing: level) + 1
        return (0...last).map { chapter(at: $0, track: track) }
    }
}
