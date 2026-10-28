import QuietCore
import Foundation
import Observation
import QuietNumbersCore
import QuietUI

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

    init(persistence: PersistenceService, gameCenter: GameCenterService = .quietNumbers()) {
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
        if let oldest = DailyKey.dayKey(todayKey, addingDays: -DailyKey.replayWindow) {
            persistence.deletePractice(before: oldest)
        }
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
        if let today = persistence.dailies[todayKey], today.isFinished || today.isCompleted {
            await gameCenter.submit(today.score, to: .daily)
        }
        await gameCenter.save(GameCenterService.Snapshot(progress: progress, dailies: persistence.dailies))
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
            record(.classicAbandoned(score: abandoned.score, played: abandoned.hasMoves))
        }
        let model = GameModel(session: GameSession(seed: .random(in: .min ... .max), scoring: unscoredScoring))
        persistence.saveGame(model.session, in: .classic)
        classicStage = model.session.stage
        start(model, as: .classic)
    }

    var hasClassicInProgress: Bool { classicStage != nil }

    /// Classic and practice: "In the Red" makes hints cheaper (a hidden reward). The scored
    /// daily challenge always uses `.standard`, so its leaderboard stays even.
    var unscoredScoring: Scoring {
        progress.unlocked.contains(.inTheRed) ? .cheapHints : .standard
    }

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

    var todayKey: String { DailyKey.dayKey(for: AppClock.now) }

    var currentStreak: Int { Streaks.current(completed: persistence.completedDays, today: todayKey) }
    var longestStreak: Int { Streaks.longest(completed: persistence.completedDays) }

    func isDailyInProgress(_ dayKey: String) -> Bool {
        openDailyKey == dayKey
    }

    /// Days with a game left halfway: today's scored attempt or any practice replay.
    var daysInProgress: Set<String> {
        persistence.practiceInProgress.union(openDailyKey.map { [$0] } ?? [])
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
        } else if let saved = persistence.loadGame(.practice(dayKey: dayKey)), !saved.isOver {
            start(GameModel(session: saved), as: .practice(dayKey: dayKey))
        } else {
            let session = DailyChallenge.session(forDayKey: dayKey, scoring: unscoredScoring)
            start(GameModel(session: session), as: .practice(dayKey: dayKey))
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
            // A new best shows up right away (Home, the game's "Best"); Game Center gets it
            // when the player leaves the game.
            if game.session.score > progress.bestScore { record(.classicScore(game.session.score)) }
        case .daily(let dayKey):
            persistence.saveGame(game.session, in: .daily)
            // Completed on reaching the goal, even if the game goes on for a higher score.
            if game.session.isCompleted { completeDaily(dayKey, score: game.session.score) }
        case .practice(let dayKey):
            persistence.saveGame(game.session, in: .practice(dayKey: dayKey))
            if game.session.isCompleted, !progress.practicedDays.contains(dayKey) {
                record(.practiceCompleted(dayKey: dayKey))
            }
        }
        if game.session.isOver { finish(game.session, kind) }
    }

    /// Back from a game: send what changed (a new best, mostly) to Game Center.
    func leftGame() {
        Task { await pushToGameCenter() }
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
        case .practice(let dayKey):
            persistence.deleteGame(.practice(dayKey: dayKey))
        }
        record(.gameFinished(classicScore: kind == .classic ? session.score : nil))
        refreshSavedGames()
        Task { await pushToGameCenter() }
    }

    /// The day counts (streak, calendar, achievements) from the move that reaches the goal;
    /// later moves only update its score.
    private func completeDaily(_ dayKey: String, score: Int) {
        let isNew = persistence.dailies[dayKey]?.isCompleted != true
        persistence.updateDaily(dayKey, score: score, isCompleted: true)
        guard isNew else { return }
        let hour = Calendar.current.component(.hour, from: AppClock.now)
        record(.dailyCompleted(currentStreak: currentStreak, localHour: hour))
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
