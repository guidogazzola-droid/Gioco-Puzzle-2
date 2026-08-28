import Foundation
import Observation
import PuzzleKit

/// Drives one board: owns the engine, the clock, and what happens on a win.
@MainActor
@Observable
final class GameViewModel {

    enum Mode: Equatable {
        case campaign(LevelTrack)
        case daily

        var track: LevelTrack {
            switch self {
            case .campaign(let track): track
            case .daily: .free
            }
        }

        var isDaily: Bool { self == .daily }
    }

    let mode: Mode
    private(set) var engine: PuzzleEngine
    /// Set once the board is solved and the result has been booked.
    private(set) var completion: Completion?
    private(set) var isShowingCompletion = false
    /// Raised when a hint is wanted but none is available.
    var isShowingHintOptions = false

    /// What the player walked away with, once the board is booked.
    struct Completion: Equatable {
        let outcome: LevelOutcome
        let dailyBonus: Int
        /// `false` when the daily had already been claimed today.
        let wasCounted: Bool
    }

    private let services: AppServices
    private var startedAt: Date
    private var pausedFor: TimeInterval = 0
    private var pauseBegan: Date?

    init(mode: Mode, level: Int, services: AppServices) {
        self.mode = mode
        self.services = services
        self.startedAt = Date()
        self.engine = PuzzleEngine(blueprint: Self.blueprint(mode: mode, level: level))
    }

    private static func blueprint(mode: Mode, level: Int) -> LevelBlueprint {
        switch mode {
        case .daily:
            DailyChallenge.blueprint(for: Date())
        case .campaign(let track):
            LevelGenerator.generate(level: level, track: track)
        }
    }

    // MARK: - Presentation

    var level: Int { engine.blueprint.level }
    var track: LevelTrack { mode.track }
    var moves: Int { engine.moves }
    var par: Int { engine.parMoves }
    var isSolved: Bool { engine.isSolved }

    var elapsedSeconds: Int {
        let paused = pausedFor + (pauseBegan.map { Date().timeIntervalSince($0) } ?? 0)
        return max(0, Int(Date().timeIntervalSince(startedAt) - paused))
    }

    var progressLabel: String {
        "\(engine.connectedColors)/\(engine.colorCount)"
    }

    var fieldLabel: String {
        "\(engine.alignedRotors)/\(engine.totalRotors)"
    }

    var fieldPercent: Int {
        Int((engine.fieldStability * 100).rounded())
    }

    /// The next campaign level, or `nil` for the daily board.
    var nextLevel: Int? {
        mode.isDaily ? nil : level + 1
    }

    // MARK: - Clock

    /// Stops the clock while an ad, a sheet or the background is in the way,
    /// so best-time records stay honest.
    func pauseClock() {
        guard pauseBegan == nil else { return }
        pauseBegan = Date()
    }

    func resumeClock() {
        guard let began = pauseBegan else { return }
        pausedFor += Date().timeIntervalSince(began)
        pauseBegan = nil
    }

    // MARK: - Input

    func begin(at cell: Coordinate) -> Bool {
        guard completion == nil else { return false }
        return engine.beginDrag(at: cell)
    }

    func extend(to cell: Coordinate) -> Bool {
        guard completion == nil else { return false }
        let moved = engine.extendDrag(to: cell)
        if moved {
            services.haptics.play(.snap)
        }
        return moved
    }

    func endDrag() {
        guard completion == nil else { return }
        let connectedBefore = engine.connectedColors
        engine.endDrag()
        if engine.connectedColors > connectedBefore {
            services.haptics.play(.connect)
        }
        if engine.isSolved { bookResult() }
    }

    @discardableResult
    func rotate(at cell: Coordinate) -> Bool {
        guard completion == nil else { return false }
        let rotated = engine.rotateRotor(at: cell)
        if rotated {
            services.haptics.play(engine.isRotorAligned(at: cell) ? .connect : .snap)
            if engine.isSolved { bookResult() }
        }
        return rotated
    }

    // MARK: - Board actions

    func reset() {
        guard completion == nil else { return }
        engine.reset()
        startedAt = Date()
        pausedFor = 0
        pauseBegan = nil
    }

    /// Spends a hint if the player has one, otherwise raises the options sheet
    /// offering a rewarded video or gems.
    func requestHint() {
        guard completion == nil else { return }
        guard services.hasFreeHint else {
            isShowingHintOptions = true
            return
        }
        guard services.consumeHint() else {
            isShowingHintOptions = true
            return
        }
        applyHint()
    }

    func applyHint() {
        guard completion == nil, engine.revealHint() != nil else { return }
        services.haptics.play(.connect)
        if engine.isSolved { bookResult() }
    }

    /// Watches a rewarded video for a hint, then applies it.
    func watchAdForHint() async {
        pauseClock()
        let earned = await services.watchRewarded(.hint)
        resumeClock()
        guard earned, services.consumeHint() else { return }
        applyHint()
    }

    func buyHintWithGems() {
        guard services.buyHintWithGems(), services.consumeHint() else { return }
        applyHint()
    }

    // MARK: - Completion

    private func bookResult() {
        guard completion == nil else { return }
        let seconds = elapsedSeconds
        pauseClock()

        switch mode {
        case .campaign(let track):
            let outcome = services.finish(engine: engine, seconds: seconds, track: track)
            completion = Completion(outcome: outcome, dailyBonus: 0, wasCounted: true)
        case .daily:
            if let daily = services.finishDaily(engine: engine, seconds: seconds) {
                completion = Completion(outcome: daily.outcome, dailyBonus: daily.bonus, wasCounted: true)
            } else {
                // Already claimed today - still celebrate, just do not pay twice.
                let parameters = DifficultyCurve.parameters(level: level, track: .free)
                let outcome = ScoreRules.outcome(
                    level: level, track: .free, parameters: parameters,
                    moves: engine.moves, par: engine.parMoves, seconds: seconds,
                    hintsUsed: engine.hintsUsed, isFirstClear: false, gemMultiplier: 1
                )
                completion = Completion(outcome: outcome, dailyBonus: 0, wasCounted: false)
            }
        }
        isShowingCompletion = true
    }

    /// Shows an interstitial if one is due, then loads the next board.
    func advance() async {
        await services.showInterstitialIfDue()
        guard let next = nextLevel else { return }
        load(level: next)
    }

    func replay() {
        load(level: level)
    }

    func load(level: Int) {
        engine = PuzzleEngine(blueprint: Self.blueprint(mode: mode, level: level))
        completion = nil
        isShowingCompletion = false
        startedAt = Date()
        pausedFor = 0
        pauseBegan = nil
    }
}
