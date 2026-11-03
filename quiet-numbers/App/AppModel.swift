import QuietCore
import Foundation
import Observation
import QuietNumbersCore
import QuietUI

/// Which game is on screen.
enum GameKind: Equatable {
    case classic
    /// An attempt at one day's challenge, as many as the player wants (2026-11-02). The day
    /// keeps its best result; completing it counts for the streak; only today's go to the
    /// daily leaderboard.
    case daily(dayKey: String)
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
    /// The daily on screen had been played to the end before: the summary says "Replay".
    private(set) var isReplay = false
    private(set) var progress: PlayerProgress
    /// Newly unlocked achievements waiting to be announced, oldest first.
    private(set) var pendingUnlocks: [Achievement] = []
    /// Achievements unlocked during the active game, for the end-of-game summary.
    private(set) var unlockedThisGame: [Achievement] = []
    /// 19:00 reminder and 21:00 "streak at risk" (QuietKit), off until allowed.
    let reminders: DailyReminders
    /// The game on screen completed a daily: on leaving it, offer the reminder (once).
    private var completedDailyThisGame = false
    /// Shows the reminder offer (`dailyReminderOffer`) back on Home.
    var offersReminders = false

    init(
        persistence: PersistenceService,
        gameCenter: GameCenterService = .quietNumbers(),
        reminders: DailyReminders = .quietNumbers()
    ) {
        self.persistence = persistence
        self.gameCenter = gameCenter
        self.reminders = reminders
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
        moveLegacyDaily()
        refreshSavedGames()
        if let oldest = DailyKey.dayKey(todayKey, addingDays: -DailyKey.replayWindow) {
            persistence.deleteDayGames(before: oldest)
        }
        gameCenter.onAuthenticated = { [weak self] in self?.syncGameCenter() }
        reminders.clock = { AppClock.now }
        reminders.state = { [weak self] in
            guard let self else { return (false, 0) }
            return (persistence.dailies[todayKey]?.isCompleted == true, currentStreak)
        }
    }

    // MARK: Reminders

    /// The background refresh (from 17:00): today's friends rewrite the 19:00 reminder.
    func refreshFriendsReminder() async {
        await reminders.refreshFriends {
            #if DEBUG
            if DemoData.isActive { return DemoData.friendsToday }
            #endif
            return await self.gameCenter.friendsToday(dailyID: GameCenterService.Leaderboard.daily.rawValue)
        }
    }

    // MARK: Achievements

    func record(_ event: ProgressEvent) {
        let unlocked = progress.record(event)
        persistence.saveProgress(progress)
        pendingUnlocks += unlocked
        unlockedThisGame += unlocked
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
        // Every attempt at today's challenge counts (2026-11-02). `daily_challenge` keeps the
        // most recent score, so what goes is the day's best: a worse attempt can't replace it,
        // and the same score in less time updates the time.
        if let today = dailyToSubmit { await gameCenter.submitDaily(today) }
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
        unlockedThisGame = []
        refreshSavedGames()
        for key in PreferenceKey.rewards + [PreferenceKey.tutorialSeen] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.set(true, forKey: PreferenceKey.pendingCloudReset)
        syncGameCenter()
        Task { await reminders.reschedule() }
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
        let model = GameModel(session: GameSession(seed: .random(in: .min ... .max), scoring: classicScoring))
        persistence.saveGame(model.session, in: .classic)
        classicStage = model.session.stage
        start(model, as: .classic)
    }

    var hasClassicInProgress: Bool { classicStage != nil }

    /// Classic only: "In the Red" makes hints cheaper (a hidden reward). Daily challenges,
    /// scored or replayed, always use `.standard` (2026-10-29: a replay is still a challenge).
    var classicScoring: Scoring {
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
        daysInProgress.contains(dayKey)
    }

    /// Days with an attempt left halfway, today or past.
    var daysInProgress: Set<String> { persistence.daysInProgress }

    /// What goes to the daily leaderboard after each attempt: today's best, once one ended.
    /// Past days never go (2026-11-02).
    var dailyToSubmit: DailyRecord? {
        persistence.dailies[todayKey].flatMap { $0.isFinished ? $0 : nil }
    }

    /// The day was already played to the end: another attempt is a replay.
    func hasPlayed(_ dayKey: String) -> Bool {
        persistence.dailies[dayKey]?.isFinished == true
    }

    /// Continues the attempt left halfway, or deals the day for a new one. The new attempt is
    /// saved right away, so it replaces whatever that day had saved.
    func playDaily(_ dayKey: String) {
        let replay = hasPlayed(dayKey)
        if let saved = persistence.loadGame(.day(dayKey)), !saved.isOver {
            start(GameModel(session: saved), as: .daily(dayKey: dayKey), replay: replay)
            return
        }
        let model = GameModel(session: DailyChallenge.session(forDayKey: dayKey))
        persistence.saveGame(model.session, in: .day(dayKey))
        start(model, as: .daily(dayKey: dayKey), replay: replay)
    }

    /// "Start over" on an attempt left halfway: the next `playDaily` deals the day again.
    func startOver(_ dayKey: String) {
        persistence.deleteGame(.day(dayKey))
    }

    /// Up to 1.2 today's scored attempt had its own slot. One still there moves to its day's
    /// slot; one saved by 1.0 past its goal (it went on after it then) is over, so it closes.
    private func moveLegacyDaily() {
        guard let daily = persistence.loadGame(.legacyDaily) else { return }
        persistence.deleteGame(.legacyDaily)
        guard case .daily(let key) = daily.mode else { return }
        if daily.isOver {
            persistence.keepBestDaily(key, score: daily.score, isCompleted: daily.isCompleted, seconds: daily.elapsedSeconds)
        } else if persistence.loadGame(.day(key)) == nil {
            persistence.saveGame(daily, in: .day(key))
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
            // Reaching the goal completes the day and ends the game (`finish`).
            if !game.session.isOver { persistence.saveGame(game.session, in: .day(dayKey)) }
        }
        if game.session.isOver { finish(game.session, kind) }
    }

    /// Back from a game: send what changed (a new best, mostly) to Game Center.
    func leftGame() {
        if completedDailyThisGame, reminders.shouldOffer { offersReminders = true }
        completedDailyThisGame = false
        Task { await pushToGameCenter() }
    }

    func start(_ model: GameModel, as kind: GameKind, replay: Bool = false) {
        model.onEvent = { [weak self] event in self?.record(event) }
        activeGame = model
        activeKind = kind
        isReplay = replay
        unlockedThisGame = []
        completedDailyThisGame = false
    }

    private func finish(_ session: GameSession, _ kind: GameKind) {
        switch kind {
        case .classic:
            persistence.deleteGame(.classic)
        case .daily(let dayKey):
            let wasCompleted = persistence.dailies[dayKey]?.isCompleted == true
            persistence.keepBestDaily(dayKey, score: session.score, isCompleted: session.isCompleted, seconds: session.elapsedSeconds)
            persistence.deleteGame(.day(dayKey))
            if session.isCompleted, !wasCompleted { dayCompleted(dayKey) }
        }
        record(.gameFinished(classicScore: kind == .classic ? session.score : nil))
        // The summary lists what this game unlocked; no banners over it.
        pendingUnlocks = []
        refreshSavedGames()
        Task { await pushToGameCenter() }
    }

    /// A day completed for the first time counts once (streak, calendar, achievements),
    /// today or past (2026-10-29: a filled gap can join two runs).
    private func dayCompleted(_ dayKey: String) {
        let hour = Calendar.current.component(.hour, from: AppClock.now)
        if dayKey == todayKey {
            record(.dailyCompleted(currentStreak: currentStreak, localHour: hour))
        } else {
            // Marks the late day on the calendar; the longest streak, since a filled gap
            // can join two runs in the past.
            if !progress.practicedDays.contains(dayKey) { record(.practiceCompleted(dayKey: dayKey)) }
            record(.dailyCompleted(currentStreak: longestStreak, localHour: hour))
        }
        completedDailyThisGame = true
        Task { await reminders.reschedule() }
    }

    private func refreshSavedGames() {
        classicStage = persistence.loadGame(.classic).flatMap { $0.isOver ? nil : $0.stage }
    }
}
