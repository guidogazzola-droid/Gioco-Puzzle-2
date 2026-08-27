import Foundation
import Observation
import PuzzleKit

/// Owns the player's save file.
///
/// The save is a single JSON document in Application Support, written
/// atomically. A puzzle game's save is small and read once at launch, so a
/// database would buy nothing; what it must never do is lose progress, hence
/// atomic writes and a quarantine copy when a file fails to decode.
@MainActor
@Observable
final class ProfileStore {

    private(set) var profile: PlayerProfile
    /// Set when a save file could not be read, so the UI can be honest about it.
    private(set) var didRecoverFromCorruptSave = false

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        (self.profile, self.didRecoverFromCorruptSave) = Self.load(from: self.fileURL)
    }

    // MARK: - Mutation

    /// Applies a change and schedules a write. Callers never touch the file.
    func update(_ mutate: (inout PlayerProfile) -> Void) {
        mutate(&profile)
        scheduleSave()
    }

    /// Writes immediately - used when the app is heading to the background.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        write(profile)
    }

    /// Coalesces bursts of small changes into one write.
    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = profile
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.write(snapshot)
        }
    }

    // MARK: - Disk

    private func write(_ profile: PlayerProfile) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(profile)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // A failed write must not take the game down mid-session; the next
            // change will try again.
            assertionFailure("Could not write profile: \(error)")
        }
    }

    private static func load(from url: URL) -> (PlayerProfile, Bool) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (PlayerProfile(), false)
        }
        do {
            let data = try Data(contentsOf: url)
            return (try JSONDecoder().decode(PlayerProfile.self, from: data), false)
        } catch {
            // Keep the unreadable file instead of overwriting it: it is the
            // only copy of that player's progress, and support may recover it.
            let quarantine = url.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: quarantine)
            try? FileManager.default.moveItem(at: url, to: quarantine)
            return (PlayerProfile(), true)
        }
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("PrismFlow", isDirectory: true)
            .appendingPathComponent("profile.json")
    }
}
