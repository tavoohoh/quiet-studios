import Foundation
import Observation
import QuietNumbersCore

/// Which game is on screen, and whether it counts.
enum GameKind: Equatable {
    case classic
    /// Today's first attempt: saved, scored, counts for the streak.
    case daily(dayKey: String)
    /// Replay of a daily (today's after finishing, or a past day). Not saved or scored.
    case practice(dayKey: String)
}

/// App-wide state: the active game, the saved classic game, and the daily challenge.
@MainActor
@Observable
final class AppModel {
    let persistence: PersistenceService
    private(set) var activeGame: GameModel?
    private(set) var activeKind: GameKind?
    /// Cached so views update when games are saved or finished.
    private(set) var hasClassicInProgress = false
    /// Day of the scored daily attempt that's still open.
    private(set) var openDailyKey: String?

    init(persistence: PersistenceService) {
        self.persistence = persistence
        refreshSavedGames()
    }

    // MARK: Classic

    func continueClassic() {
        guard let session = persistence.loadGame(.classic), !session.isOver else { return newClassic() }
        start(GameModel(session: session), as: .classic)
    }

    func newClassic() {
        let model = GameModel()
        persistence.saveGame(model.session, in: .classic)
        hasClassicInProgress = true
        start(model, as: .classic)
    }

    // MARK: Daily

    var todayKey: String { DailyChallenge.dayKey(for: .now) }

    var currentStreak: Int { Streaks.current(completed: persistence.completedDays, today: todayKey) }
    var longestStreak: Int { Streaks.longest(completed: persistence.completedDays) }

    func isDailyInProgress(_ dayKey: String) -> Bool {
        openDailyKey == dayKey
    }

    /// Whether playing `dayKey` now would count.
    func isScored(_ dayKey: String) -> Bool {
        isDailyInProgress(dayKey) || (dayKey == todayKey && persistence.dailies[dayKey] == nil)
    }

    func playDaily(_ dayKey: String) {
        if isDailyInProgress(dayKey), let session = persistence.loadGame(.daily) {
            start(GameModel(session: session), as: .daily(dayKey: dayKey))
        } else if isScored(dayKey) {
            let model = GameModel(session: DailyChallenge.session(forDayKey: dayKey))
            persistence.startDaily(dayKey)
            persistence.saveGame(model.session, in: .daily)
            openDailyKey = dayKey
            start(model, as: .daily(dayKey: dayKey))
        } else {
            start(GameModel(session: DailyChallenge.session(forDayKey: dayKey)), as: .practice(dayKey: dayKey))
        }
    }

    // MARK: Active game

    /// After every move.
    func sessionChanged() {
        guard let game = activeGame, let kind = activeKind else { return }
        switch kind {
        case .classic: persistence.saveGame(game.session, in: .classic)
        case .daily: persistence.saveGame(game.session, in: .daily)
        case .practice: break
        }
        if game.session.isOver { finish(game.session, kind) }
    }

    func start(_ model: GameModel, as kind: GameKind) {
        activeGame = model
        activeKind = kind
    }

    private func finish(_ session: GameSession, _ kind: GameKind) {
        switch kind {
        case .classic:
            persistence.deleteGame(.classic)
        case .daily(let dayKey):
            persistence.finishDaily(dayKey, score: session.score, isCompleted: session.isCompleted)
            persistence.deleteGame(.daily)
        case .practice:
            break
        }
        refreshSavedGames()
    }

    private func refreshSavedGames() {
        hasClassicInProgress = persistence.loadGame(.classic).map { !$0.isOver } ?? false
        if let daily = persistence.loadGame(.daily), !daily.isOver, case .daily(let key) = daily.mode {
            openDailyKey = key
        } else {
            openDailyKey = nil
        }
    }
}
