import Foundation
import Observation
import QuietCore
import QuietSudokuCore
import QuietUI

/// Which game is on screen.
enum GameKind: Equatable {
    case classic
    /// A day's challenge, today's or one of the last 30, saved per day (2026-11-02, the
    /// family's daily rule). Every attempt counts the same: a win keeps the day's best,
    /// today's goes to the daily leaderboard, a past day's first win fills the streak.
    /// `isReplay`: not the day's first attempt (only the label changes).
    case daily(dayKey: String, isReplay: Bool)
}

/// Leaderboards, the same three as Quiet Numbers.
enum Leaderboard: String, CaseIterable {
    /// Recurring, resets every 24 h. Today's best result.
    case daily = "qsu_daily_challenge"
    case bestScore = "qsu_best_score"
    case longestStreak = "qsu_longest_streak"
}

/// Progress and daily results shared across the player's devices (Game Center saved game).
struct Snapshot: Codable {
    var progress: PlayerProgress
    var dailies: [String: DailyRecord]

    /// Keeps the most progress from both.
    func merged(with other: Snapshot) -> Snapshot {
        var dailies = self.dailies
        for (day, record) in other.dailies {
            dailies[day] = dailies[day].map { $0.better(than: record) } ?? record
        }
        return Snapshot(progress: progress.merged(with: other.progress), dailies: dailies)
    }
}

/// App-wide state: the active game, the saved classic game, and the daily challenge.
@MainActor
@Observable
final class AppModel {
    let persistence: PersistenceService
    let gameCenter: GameCenterService
    /// 19:00 reminder and 21:00 "streak at risk" (QuietKit), off until allowed.
    let reminders: DailyReminders
    private(set) var activeGame: GameModel?
    private(set) var activeKind: GameKind?
    /// Classic best when the active game started (for "Best" and "New record!").
    private(set) var bestAtStart = 0
    /// Achievements unlocked during the active game, for the win sheet.
    private(set) var unlockedThisGame: [Achievement] = []
    /// Level of the saved classic game, if one is in progress.
    private(set) var classicInProgress: Difficulty?
    private(set) var progress: PlayerProgress
    /// Newly unlocked achievements waiting to be announced during play.
    private(set) var pendingUnlocks: [Achievement] = []
    /// A puzzle is being generated (expert ones take a moment).
    private(set) var isPreparing = false
    /// The game on screen completed a daily: on leaving it, offer the reminder (once).
    private var completedDailyThisGame = false
    /// Shows the reminder offer (`dailyReminderOffer`) back on Home.
    var offersReminders = false

    private var dailyPuzzles: [String: Puzzle] = [:]
    /// The next classic puzzle per level, made in the background so "New Game" is instant.
    private var nextPuzzles: [Difficulty: Puzzle] = [:]

    init(
        persistence: PersistenceService,
        gameCenter: GameCenterService = GameCenterService(subsystem: "com.tavoohoh.quietsudoku"),
        reminders: DailyReminders = .quietSudoku()
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
        refreshSavedGames()
        if let oldest = DailyKey.dayKey(todayKey, addingDays: -DailyKey.replayWindow) {
            persistence.deleteDailyGames(before: oldest)
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
            return await self.gameCenter.friendsToday(dailyID: Leaderboard.daily.rawValue)
        }
    }

    // MARK: Achievements

    func record(_ event: ProgressEvent) {
        let unlocked = progress.record(event)
        persistence.saveProgress(progress)
        pendingUnlocks += unlocked
        unlockedThisGame += unlocked
        if !unlocked.isEmpty {
            let percentages = achievementPercentages
            Task { await gameCenter.report(percentages) }
        }
    }

    func dismissUnlock(_ achievement: Achievement) {
        pendingUnlocks.removeAll { $0 == achievement }
    }

    private var achievementPercentages: [String: Double] {
        Dictionary(uniqueKeysWithValues: Achievement.allCases.map { ($0.gameCenterID, progress.progress(of: $0) * 100) })
    }

    // MARK: Game Center

    /// On sign-in: pull what other devices saved, merge it into local data, then push everything.
    func syncGameCenter() {
        Task {
            // A reset made while signed out still has to clear the cloud copy, or it would merge back.
            if UserDefaults.standard.bool(forKey: PreferenceKey.pendingCloudReset) {
                guard await gameCenter.resetCloud() else { return }
                UserDefaults.standard.removeObject(forKey: PreferenceKey.pendingCloudReset)
            } else if let remote = await gameCenter.fetchSnapshot(Snapshot.self, merge: { $0.merged(with: $1) }) {
                progress = progress.merged(with: remote.progress)
                persistence.saveProgress(progress)
                persistence.mergeDailies(remote.dailies)
            }
            await pushToGameCenter()
        }
    }

    private func pushToGameCenter() async {
        await gameCenter.report(achievementPercentages)
        await gameCenter.submit(progress.bestScore, to: Leaderboard.bestScore.rawValue)
        await gameCenter.submit(longestStreak, to: Leaderboard.longestStreak.rawValue)
        if let today = persistence.dailies[todayKey], today.isFinished {
            // Today's best, after every attempt: the board keeps the most recent score, so
            // sending the best is what keeps the best there. The time rides in the context:
            // the app breaks ties with it (`rankedByScoreAndTime`).
            await gameCenter.submit(today.score, to: Leaderboard.daily.rawValue, always: true,
                                    context: GameCenterService.dailyContext(seconds: today.seconds))
        }
        await gameCenter.save(Snapshot(progress: progress, dailies: persistence.dailies))
    }

    // MARK: Reset

    /// Erases all progress here and in iCloud / Game Center. Sound, haptics and options stay.
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
        Task { await reminders.reschedule() }
    }

    // MARK: Classic

    var hasClassicInProgress: Bool { classicInProgress != nil }

    /// The level offered first for a new classic game: the last one played.
    var lastClassicDifficulty: Difficulty {
        Difficulty(rawValue: UserDefaults.standard.integer(forKey: PreferenceKey.classicDifficulty)) ?? .easy
    }

    func continueClassic() async {
        guard let session = persistence.loadGame(.classic), !session.isWon else { return await newClassic(lastClassicDifficulty) }
        start(GameModel(session: session), as: .classic)
    }

    /// A fresh puzzle of `difficulty`, generated on device (off the main thread).
    func newClassic(_ difficulty: Difficulty) async {
        if let abandoned = persistence.loadGame(.classic), !abandoned.isWon {
            record(.abandoned(played: abandoned.hasPlayed))
        }
        UserDefaults.standard.set(difficulty.rawValue, forKey: PreferenceKey.classicDifficulty)
        let puzzle: Puzzle
        if let ready = nextPuzzles.removeValue(forKey: difficulty) {
            puzzle = ready
        } else {
            isPreparing = true
            puzzle = await Self.makeClassic(difficulty, priority: .userInitiated)
            isPreparing = false
        }
        warmUpClassic(difficulty)
        let model = GameModel(session: GameSession(puzzle: puzzle, scoring: classicScoring))
        persistence.saveGame(model.session, in: .classic)
        classicInProgress = difficulty
        self.start(model, as: .classic)
    }

    /// The same puzzle again from the start. A daily starts a new attempt, which replaces
    /// the saved one.
    func restart() {
        guard let game = activeGame, let kind = activeKind else { return }
        let session = GameSession(mode: game.session.mode, puzzle: game.session.puzzle, scoring: game.session.scoring)
        switch kind {
        case .classic:
            persistence.saveGame(session, in: .classic)
            classicInProgress = session.difficulty
            start(GameModel(session: session), as: .classic)
        case .daily:
            startAttempt(session)
        }
    }

    /// First "New Game" of someone who never played: the tutorial comes first.
    /// UI tests skip it unless launched with `-tutorial`.
    var needsTutorial: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTesting"), !arguments.contains("-tutorial") { return false }
        #endif
        return !UserDefaults.standard.bool(forKey: PreferenceKey.tutorialSeen)
            && progress.gamesPlayed == 0 && !hasClassicInProgress
    }

    func finishTutorial() {
        UserDefaults.standard.set(true, forKey: PreferenceKey.tutorialSeen)
    }

    /// Classic only: "In the Red" makes hints cheaper (a hidden reward). Daily challenges,
    /// today's or past, always use `.standard` (2026-10-30, the family's daily rule).
    var classicScoring: Scoring {
        progress.unlocked.contains(.inTheRed) ? .cheapHints : .standard
    }

    /// A random puzzle of `difficulty`, off the main thread.
    private static func makeClassic(_ difficulty: Difficulty, priority: TaskPriority) async -> Puzzle {
        let key = "classic-\(UInt64.random(in: .min ... .max))"
        return await Task.detached(priority: priority) { Generator.puzzle(key: key, difficulty: difficulty) }.value
    }

    /// Prepares the next classic puzzle of `difficulty` (default: the last level played).
    func warmUpClassic(_ difficulty: Difficulty? = nil) {
        let level = difficulty ?? lastClassicDifficulty
        guard nextPuzzles[level] == nil else { return }
        Task {
            let puzzle = await Self.makeClassic(level, priority: .utility)
            if nextPuzzles[level] == nil { nextPuzzles[level] = puzzle }
        }
    }

    // MARK: Daily

    var todayKey: String { DailyKey.dayKey(for: AppClock.now) }

    var currentStreak: Int { Streaks.current(completed: persistence.completedDays, today: todayKey) }
    var longestStreak: Int { Streaks.longest(completed: persistence.completedDays) }

    /// Days with an attempt left halfway (a dot on the calendar; "Continue").
    var daysInProgress: Set<String> { persistence.dailiesInProgress }

    func isDailyInProgress(_ dayKey: String) -> Bool { daysInProgress.contains(dayKey) }

    /// Resumes the day's attempt in progress, or starts a new one. The calendar asks
    /// "Continue / Start over" first (`startOver`).
    func playDaily(_ dayKey: String) async {
        if let saved = persistence.loadGame(.daily(dayKey: dayKey)), !saved.isWon {
            return start(GameModel(session: saved), as: dailyKind(dayKey))
        }
        startAttempt(GameSession(mode: .daily(dayKey: dayKey), puzzle: await dailyPuzzle(dayKey)))
    }

    /// "Start over": drops the saved attempt, so the next `playDaily` starts a new one.
    func startOver(_ dayKey: String) {
        persistence.deleteGame(.daily(dayKey: dayKey))
    }

    /// A new attempt at a daily, saved right away in its day's slot. That slot holds only
    /// the attempt in progress: never the state of an earlier one (bug found in Quiet Numbers,
    /// 2026-11-02).
    private func startAttempt(_ session: GameSession) {
        guard case .daily(let dayKey) = session.mode else { return }
        persistence.startAttempt(dayKey)
        persistence.saveGame(session, in: .daily(dayKey: dayKey))
        start(GameModel(session: session), as: dailyKind(dayKey))
    }

    private func dailyKind(_ dayKey: String) -> GameKind {
        .daily(dayKey: dayKey, isReplay: persistence.attempts(dayKey) > 1)
    }

    /// The generator builds the day's puzzle (a fraction of a second; cached for the session).
    private func dailyPuzzle(_ dayKey: String) async -> Puzzle {
        if let puzzle = dailyPuzzles[dayKey] { return puzzle }
        isPreparing = true
        let puzzle = await Task.detached(priority: .userInitiated) { DailyChallenge.puzzle(forDayKey: dayKey) }.value
        isPreparing = false
        dailyPuzzles[dayKey] = puzzle
        return puzzle
    }

    /// Prepares today's puzzle in the background so "Play" starts right away.
    func warmUpDaily() {
        let today = todayKey
        guard dailyPuzzles[today] == nil else { return }
        Task {
            let puzzle = await Task.detached(priority: .utility) { DailyChallenge.puzzle(forDayKey: today) }.value
            dailyPuzzles[today] = puzzle
        }
    }

    // MARK: Active game

    func start(_ model: GameModel, as kind: GameKind) {
        model.onProgress = { [weak self] event in self?.record(event) }
        model.onChange = { [weak self] in self?.sessionChanged() }
        bestAtStart = progress.bestScore
        unlockedThisGame = []
        completedDailyThisGame = false
        activeGame = model
        activeKind = kind
    }

    /// After every action.
    private func sessionChanged() {
        guard let game = activeGame, let kind = activeKind else { return }
        persistence.saveGame(game.session, in: slot(for: kind))
        if game.session.isWon { finish(game.session, kind) }
    }

    /// Back from a game: keep its clock, and send what changed to Game Center.
    func leftGame() {
        saveActiveGame()
        if completedDailyThisGame, reminders.shouldOffer { offersReminders = true }
        completedDailyThisGame = false
        Task { await pushToGameCenter() }
    }

    /// Saves the game on screen (its clock moves without actions). Also on going to background.
    func saveActiveGame() {
        guard let game = activeGame, let kind = activeKind, !game.session.isWon else { return }
        persistence.saveGame(game.session, in: slot(for: kind))
    }

    private func slot(for kind: GameKind) -> PersistenceService.Slot {
        switch kind {
        case .classic: .classic
        case .daily(let dayKey, _): .daily(dayKey: dayKey)
        }
    }

    private func finish(_ session: GameSession, _ kind: GameKind) {
        switch kind {
        case .classic:
            persistence.deleteGame(.classic)
        case .daily(let dayKey, _):
            persistence.deleteGame(.daily(dayKey: dayKey))
            // Every win keeps the day's best; today's reaches the leaderboard below.
            if persistence.recordWin(dayKey, score: session.score, seconds: session.elapsedSeconds) {
                if dayKey != todayKey { record(.completedLate(dayKey: dayKey)) }
                let hour = Calendar.current.component(.hour, from: AppClock.now)
                // A past day can join two runs, so the longest streak, not today's.
                record(.dailyCompleted(currentStreak: longestStreak, localHour: hour))
                completedDailyThisGame = true
            }
        }
        refreshSavedGames()
        Task {
            await reminders.reschedule()
            await pushToGameCenter()
        }
    }

    private func refreshSavedGames() {
        classicInProgress = persistence.loadGame(.classic).flatMap { $0.isWon ? nil : $0.difficulty }
    }
}
