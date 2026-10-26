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
    let gameCenter: GameCenterService
    private(set) var activeGame: GameModel?
    private(set) var activeKind: GameKind?
    /// Stage of the saved classic game, if one is in progress. Cached so views update
    /// when games are saved or finished.
    private(set) var classicStage: Int?
    /// Day of the scored daily attempt that's still open.
    private(set) var openDailyKey: String?
    private(set) var progress: PlayerProgress
    /// Newly unlocked achievements waiting to be announced, oldest first.
    private(set) var pendingUnlocks: [Achievement] = []

    init(persistence: PersistenceService, gameCenter: GameCenterService = GameCenterService()) {
        self.persistence = persistence
        self.gameCenter = gameCenter
        progress = persistence.loadProgress()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetStore") {
            UserDefaults.standard.removeObject(forKey: PreferenceKey.tutorialSeen)
        }
        if ProcessInfo.processInfo.arguments.contains("-unlockAll") {
            progress = PlayerProgress(unlocked: Set(Achievement.allCases))
        }
        if DemoData.isActive {
            progress = DemoData.progress
            DemoData.seed(persistence)
        }
        #endif
        refreshSavedGames()
        gameCenter.onAuthenticated = { [weak self] in self?.syncGameCenter() }
    }

    // MARK: Achievements

    func record(_ event: ProgressEvent) {
        let unlocked = progress.record(event)
        persistence.saveProgress(progress)
        pendingUnlocks += unlocked
        if !unlocked.isEmpty {
            let progress = progress
            Task { await gameCenter.report(progress) }
        }
    }

    // MARK: Game Center

    /// On sign-in: pull what other devices saved, merge it into local data, then push everything.
    func syncGameCenter() {
        Task {
            // A reset made while signed out still has to clear the cloud copy, or it would merge back.
            if UserDefaults.standard.bool(forKey: PreferenceKey.pendingCloudReset) {
                guard await gameCenter.resetCloud() else { return }
                UserDefaults.standard.removeObject(forKey: PreferenceKey.pendingCloudReset)
            } else if let remote = await gameCenter.fetchSnapshot() {
                progress = progress.merged(with: remote.progress)
                persistence.saveProgress(progress)
                persistence.mergeDailies(remote.dailies)
            }
            await pushToGameCenter()
        }
    }

    private func pushToGameCenter() async {
        await gameCenter.report(progress)
        await gameCenter.submit(progress.bestScore, to: .bestScore)
        await gameCenter.submit(longestStreak, to: .longestStreak)
        if let today = persistence.dailies[todayKey], today.isFinished {
            await gameCenter.submit(today.score, to: .daily)
        }
        await gameCenter.save(.init(progress: progress, dailies: persistence.dailies))
    }

    // MARK: Reset

    /// Erases all progress here and in iCloud / Game Center: games, dailies, streaks,
    /// achievements and the rewards they unlocked. Sound, haptics and text size stay.
    /// Signed out, the cloud part waits for the next sign-in.
    func resetProgress() {
        persistence.deleteEverything()
        progress = PlayerProgress()
        persistence.saveProgress(progress)
        activeGame = nil
        activeKind = nil
        pendingUnlocks = []
        refreshSavedGames()
        for key in PreferenceKey.rewards + [PreferenceKey.tutorialSeen] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.set(true, forKey: PreferenceKey.pendingCloudReset)
        syncGameCenter()
    }

    func dismissUnlock(_ achievement: Achievement) {
        pendingUnlocks.removeAll { $0 == achievement }
    }

    // MARK: Classic

    func continueClassic() {
        guard let session = persistence.loadGame(.classic), !session.isOver else { return newClassic() }
        start(GameModel(session: session), as: .classic)
    }

    func newClassic() {
        if let abandoned = persistence.loadGame(.classic), !abandoned.isOver {
            record(.classicAbandoned(score: abandoned.score))
        }
        let model = GameModel()
        persistence.saveGame(model.session, in: .classic)
        classicStage = model.session.stage
        start(model, as: .classic)
    }

    var hasClassicInProgress: Bool { classicStage != nil }

    /// First "New Game" of someone who never played: the tutorial comes first.
    /// UI tests skip it unless launched with `-tutorial`.
    var needsTutorial: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTesting"), !arguments.contains("-tutorial") { return false }
        #endif
        return !UserDefaults.standard.bool(forKey: PreferenceKey.tutorialSeen)
            && progress.gamesFinished == 0 && !hasClassicInProgress
    }

    func finishTutorial() {
        UserDefaults.standard.set(true, forKey: PreferenceKey.tutorialSeen)
    }

    // MARK: Daily

    var todayKey: String { DailyChallenge.dayKey(for: AppClock.now) }

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
        case .classic:
            persistence.saveGame(game.session, in: .classic)
            classicStage = game.session.stage
        case .daily: persistence.saveGame(game.session, in: .daily)
        case .practice: break
        }
        if game.session.isOver { finish(game.session, kind) }
    }

    func start(_ model: GameModel, as kind: GameKind) {
        model.onEvent = { [weak self] event in self?.record(event) }
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
            if session.isCompleted {
                let hour = Calendar.current.component(.hour, from: AppClock.now)
                record(.dailyCompleted(currentStreak: currentStreak, localHour: hour))
            }
        case .practice:
            break
        }
        record(.gameFinished(classicScore: kind == .classic ? session.score : nil, hintsUsed: session.hintsUsed))
        refreshSavedGames()
        Task { await pushToGameCenter() }
    }

    private func refreshSavedGames() {
        classicStage = persistence.loadGame(.classic).flatMap { $0.isOver ? nil : $0.stage }
        if let daily = persistence.loadGame(.daily), !daily.isOver, case .daily(let key) = daily.mode {
            openDailyKey = key
        } else {
            openDailyKey = nil
        }
    }
}
