import Foundation
import Observation
import QuietCore
import QuietSudokuCore
import QuietUI

/// Which game is on screen, and whether it counts.
enum GameKind: Equatable {
    case classic
    /// Today's first attempt: saved, scored, counts for the streak.
    case daily(dayKey: String)
    /// Replay of a daily (today's after the scored attempt, or a past day). Saved per day,
    /// not scored; winning it fills that day for the streak.
    case practice(dayKey: String)
}

/// Leaderboards, the same three as Quiet Numbers.
enum Leaderboard: String, CaseIterable {
    /// Recurring, resets every 24 h. Today's scored daily attempt (latest result).
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
    /// Day of the scored daily attempt that's still open.
    private(set) var openDailyKey: String?
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
            persistence.deletePractice(before: oldest)
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
            // The time rides in the context: the app breaks ties with it (`rankedByScoreAndTime`).
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

    /// The same puzzle again from the start (classic stays classic; a daily replay is practice).
    func restart() {
        guard let game = activeGame, let kind = activeKind else { return }
        let session = GameSession(mode: game.session.mode, puzzle: game.session.puzzle, scoring: game.session.scoring)
        switch kind {
        case .classic:
            persistence.saveGame(session, in: .classic)
            classicInProgress = session.difficulty
            start(GameModel(session: session), as: .classic)
        case .daily(let day):
            // The scored attempt keeps its score; the restart is practice.
            start(GameModel(session: GameSession(mode: session.mode, puzzle: session.puzzle)), as: .practice(dayKey: day))
        case .practice(let day):
            persistence.saveGame(session, in: .practice(dayKey: day))
            start(GameModel(session: session), as: kind)
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
    /// scored or replayed, always use `.standard` (2026-10-30, the family's daily rule).
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

    func isDailyInProgress(_ dayKey: String) -> Bool { openDailyKey == dayKey }

    /// Days with a game left halfway: today's scored attempt or any practice replay.
    var daysInProgress: Set<String> {
        persistence.practiceInProgress.union(openDailyKey.map { [$0] } ?? [])
    }

    /// Whether playing `dayKey` now would count.
    func isScored(_ dayKey: String) -> Bool {
        isDailyInProgress(dayKey) || (dayKey == todayKey && persistence.dailies[dayKey] == nil)
    }

    func playDaily(_ dayKey: String) async {
        if isDailyInProgress(dayKey), let session = persistence.loadGame(.daily) {
            return start(GameModel(session: session), as: .daily(dayKey: dayKey))
        }
        let puzzle = await dailyPuzzle(dayKey)
        if isScored(dayKey) {
            let model = GameModel(session: GameSession(mode: .daily(dayKey: dayKey), puzzle: puzzle))
            persistence.startDaily(dayKey)
            persistence.saveGame(model.session, in: .daily)
            openDailyKey = dayKey
            start(model, as: .daily(dayKey: dayKey))
        } else if let saved = persistence.loadGame(.practice(dayKey: dayKey)), !saved.isWon {
            start(GameModel(session: saved), as: .practice(dayKey: dayKey))
        } else {
            let session = GameSession(mode: .daily(dayKey: dayKey), puzzle: puzzle)
            start(GameModel(session: session), as: .practice(dayKey: dayKey))
        }
    }

    /// "Start over" on a practice left halfway: the next `playDaily` starts the day again.
    func discardPractice(_ dayKey: String) {
        persistence.deleteGame(.practice(dayKey: dayKey))
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
        switch kind {
        case .classic:
            persistence.saveGame(game.session, in: .classic)
        case .daily: persistence.saveGame(game.session, in: .daily)
        case .practice(let day): persistence.saveGame(game.session, in: .practice(dayKey: day))
        }
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
        guard let game = activeGame, !game.session.isWon else { return }
        switch activeKind {
        case .classic: persistence.saveGame(game.session, in: .classic)
        case .daily: persistence.saveGame(game.session, in: .daily)
        case .practice(let day): persistence.saveGame(game.session, in: .practice(dayKey: day))
        case nil: break
        }
    }

    private func finish(_ session: GameSession, _ kind: GameKind) {
        switch kind {
        case .classic:
            persistence.deleteGame(.classic)
        case .daily(let dayKey):
            persistence.finishDaily(dayKey, score: session.score, isCompleted: true, seconds: session.elapsedSeconds)
            persistence.deleteGame(.daily)
            let hour = Calendar.current.component(.hour, from: AppClock.now)
            record(.dailyCompleted(currentStreak: currentStreak, localHour: hour))
            completedDailyThisGame = true
        case .practice(let dayKey):
            persistence.deleteGame(.practice(dayKey: dayKey))
            if !progress.practicedDays.contains(dayKey) { record(.practiceCompleted(dayKey: dayKey)) }
            fillDay(dayKey, with: session)
        }
        refreshSavedGames()
        Task {
            await reminders.reschedule()
            await pushToGameCenter()
        }
    }

    /// A missed (or unfinished) day won as practice fills the streak (2026-10-30, as in Quiet
    /// Numbers). It counts like a completed daily for achievements, but sends nothing to the
    /// daily board.
    private func fillDay(_ dayKey: String, with session: GameSession) {
        guard persistence.dailies[dayKey]?.isCompleted != true else { return }
        persistence.fillDaily(dayKey, score: session.score, seconds: session.elapsedSeconds)
        let hour = Calendar.current.component(.hour, from: AppClock.now)
        // A filled gap can join two runs in the past, so the longest streak, not today's.
        record(.dailyCompleted(currentStreak: longestStreak, localHour: hour))
        completedDailyThisGame = true
    }

    private func refreshSavedGames() {
        classicInProgress = persistence.loadGame(.classic).flatMap { $0.isWon ? nil : $0.difficulty }
        if let daily = persistence.loadGame(.daily), !daily.isWon, case .daily(let key) = daily.mode {
            openDailyKey = key
        } else {
            openDailyKey = nil
        }
    }
}
