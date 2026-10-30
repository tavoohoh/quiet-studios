import Foundation
import Observation
import QuietCore
import QuietSolitaireCore
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
    case daily = "qs_daily_challenge"
    case bestScore = "qs_best_score"
    case longestStreak = "qs_longest_streak"
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
    /// Moves of the saved classic game, if one is in progress.
    private(set) var classicMoves: Int?
    /// Day of the scored daily attempt that's still open.
    private(set) var openDailyKey: String?
    private(set) var progress: PlayerProgress
    /// Newly unlocked achievements waiting to be announced during play.
    private(set) var pendingUnlocks: [Achievement] = []
    /// A deal is being checked by the solver (daily deals take a moment).
    private(set) var isPreparing = false
    /// The game on screen completed a daily: on leaving it, offer the reminder (once).
    private var completedDailyThisGame = false
    /// Shows the reminder offer (`dailyReminderOffer`) back on Home.
    var offersReminders = false

    private var dailySeeds: [String: UInt64] = [:]
    /// The next winnable classic deal, searched ahead so "New Game" opens at once.
    private var nextWinnableSeed: Task<UInt64, Never>?

    init(
        persistence: PersistenceService,
        gameCenter: GameCenterService = GameCenterService(subsystem: "com.tavoohoh.quietsolitaire"),
        reminders: DailyReminders = .quietSolitaire()
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

    var hasClassicInProgress: Bool { classicMoves != nil }

    func continueClassic() async {
        guard let session = persistence.loadGame(.classic), !session.isWon else {
            await newClassic()
            return
        }
        start(GameModel(session: session), as: .classic)
    }

    /// A fresh deal; with "Only winnable deals" on (the default), one the solver can win.
    /// False if a deal was already being prepared: repeated taps while the solver searched
    /// used to open several games (2026-10-30).
    @discardableResult
    func newClassic() async -> Bool {
        guard !isPreparing else { return false }
        isPreparing = true
        defer { isPreparing = false }
        if let abandoned = persistence.loadGame(.classic), !abandoned.isWon {
            record(.abandoned(played: abandoned.hasMoves))
            if abandoned.score > progress.bestScore { record(.classicScore(abandoned.score)) }
        }
        let winnableOnly = UserDefaults.standard.object(forKey: PreferenceKey.winnableOnly) as? Bool ?? true
        let seed: UInt64
        if winnableOnly {
            if nextWinnableSeed == nil { warmUpClassic() }
            seed = await nextWinnableSeed?.value ?? .random(in: .min ... .max)
            warmUpClassic()
        } else {
            seed = .random(in: .min ... .max)
        }
        let model = GameModel(session: GameSession(seed: seed, scoring: classicScoring))
        persistence.saveGame(model.session, in: .classic)
        classicMoves = 0
        self.start(model, as: .classic)
        return true
    }

    /// The same deal again from the start (classic stays classic; a daily replay is practice).
    func restart() {
        guard let game = activeGame, let kind = activeKind else { return }
        let session = GameSession(mode: game.session.mode, seed: game.session.seed, scoring: game.session.scoring)
        switch kind {
        case .classic:
            persistence.saveGame(session, in: .classic)
            classicMoves = 0
            start(GameModel(session: session), as: .classic)
        case .daily(let day):
            // The scored attempt keeps its score; the restart is practice.
            start(GameModel(session: GameSession(mode: session.mode, seed: session.seed)), as: .practice(dayKey: day))
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
        let seed = await dailySeed(dayKey)
        if isScored(dayKey) {
            let model = GameModel(session: GameSession(mode: .daily(dayKey: dayKey), seed: seed))
            persistence.startDaily(dayKey)
            persistence.saveGame(model.session, in: .daily)
            openDailyKey = dayKey
            start(model, as: .daily(dayKey: dayKey))
        } else if let saved = persistence.loadGame(.practice(dayKey: dayKey)), !saved.isWon {
            start(GameModel(session: saved), as: .practice(dayKey: dayKey))
        } else {
            let session = GameSession(mode: .daily(dayKey: dayKey), seed: seed)
            start(GameModel(session: session), as: .practice(dayKey: dayKey))
        }
    }

    /// "Start over" on a practice left halfway: the next `playDaily` deals the day again.
    func discardPractice(_ dayKey: String) {
        persistence.deleteGame(.practice(dayKey: dayKey))
    }

    /// The solver picks the day's deal (a fraction of a second; cached for the session).
    private func dailySeed(_ dayKey: String) async -> UInt64 {
        if let seed = dailySeeds[dayKey] { return seed }
        isPreparing = true
        let seed = await Task.detached(priority: .userInitiated) { Deals.dailySeed(forDayKey: dayKey) }.value
        isPreparing = false
        dailySeeds[dayKey] = seed
        return seed
    }

    /// Searches the next winnable classic deal in the background (several deals can take
    /// the solver a few seconds).
    func warmUpClassic() {
        let start = UInt64.random(in: .min ... .max)
        nextWinnableSeed = Task.detached(priority: .utility) { Deals.winnableSeed(startingAt: start) }
    }

    /// Prepares today's deal in the background so "Play" starts right away.
    func warmUpDaily() {
        let today = todayKey
        guard dailySeeds[today] == nil else { return }
        Task {
            let seed = await Task.detached(priority: .utility) { Deals.dailySeed(forDayKey: today) }.value
            dailySeeds[today] = seed
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

    /// After every move.
    private func sessionChanged() {
        guard let game = activeGame, let kind = activeKind else { return }
        switch kind {
        case .classic:
            persistence.saveGame(game.session, in: .classic)
            classicMoves = game.session.moves
            if game.session.score > progress.bestScore { record(.classicScore(game.session.score)) }
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

    /// Saves the game on screen (its clock moves without moves). Also on going to background.
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
        classicMoves = persistence.loadGame(.classic).flatMap { $0.isWon ? nil : $0.moves }
        if let daily = persistence.loadGame(.daily), !daily.isWon, case .daily(let key) = daily.mode {
            openDailyKey = key
        } else {
            openDailyKey = nil
        }
    }
}
