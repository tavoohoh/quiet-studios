import Foundation
import QuietCore
import QuietSudokuCore
import QuietUI
import Testing
@testable import Quiet_Sudoku

/// The family's daily rule (root CLAUDE.md, "Reto diario"), as Quiet Sudoku plays it.
@MainActor
@Suite struct DailyRuleTests {
    private func makeApp(_ persistence: PersistenceService = PersistenceService(store: .inMemory)) -> AppModel {
        AppModel(persistence: persistence)
    }

    /// A board one digit from the win.
    private func oneMoveFromWin(_ mode: GameSession.Mode, seconds: Int = 0) -> GameModel {
        TestBoards.oneFromWin(mode, seconds: seconds)
    }

    /// An attempt at `dayKey` won with `seconds` on the clock; returns its score.
    @discardableResult
    private func win(_ app: AppModel, _ dayKey: String, seconds: Int = 0, mistakes: Int = 0) -> Int {
        app.persistence.startAttempt(dayKey)
        let model = oneMoveFromWin(.daily(dayKey: dayKey), seconds: seconds)
        for _ in 0..<mistakes { model.writeAMistake() }
        app.start(model, as: .daily(dayKey: dayKey, isReplay: app.persistence.attempts(dayKey) > 1))
        model.playLastCell()
        return model.session.score
    }

    @Test func playingADaySavesItsAttempt() async throws {
        let app = makeApp()
        let yesterday = try #require(DailyKey.dayKey(app.todayKey, addingDays: -1))
        await app.playDaily(yesterday)
        #expect(app.activeKind == .daily(dayKey: yesterday, isReplay: false))
        let game = try #require(app.activeGame)
        game.writeANote()
        #expect(app.daysInProgress.contains(yesterday))
        // Back to the same day: the same game, not a new puzzle.
        await app.playDaily(yesterday)
        #expect(app.activeGame !== game)
        #expect(app.activeGame?.session == game.session)
        #expect(app.persistence.dailies[yesterday]?.isCompleted != true)
    }

    @Test func startingOverStartsANewAttempt() async throws {
        let app = makeApp()
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: -2))
        await app.playDaily(day)
        app.activeGame?.writeANote()
        app.startOver(day)
        #expect(!app.daysInProgress.contains(day))
        await app.playDaily(day)
        #expect(app.activeGame?.session.actions == 0)
        // Any attempt after the first is a replay.
        #expect(app.activeKind == .daily(dayKey: day, isReplay: true))
    }

    /// Bug found in Quiet Numbers (2026-11-02): start, start over, play, leave, and coming
    /// back showed the first attempt. What's saved is always the attempt in progress.
    private func expectLatestAttemptResumes(_ dayKey: String) async throws {
        // On disk, so "leaving the app" reopens the file like a new launch does.
        let store = "daily-restart-\(dayKey)"
        let app = makeApp(PersistenceService(store: .named(store, reset: true)))
        await app.playDaily(dayKey)
        app.activeGame?.writeANote(1)
        app.restart()
        let latest = try #require(app.activeGame)
        latest.writeANote(2)
        latest.writeANote(3)
        app.leftGame()
        await app.playDaily(dayKey)
        #expect(app.activeGame?.session == latest.session)
        // Leaving the app: a new launch opens the same file.
        let relaunched = makeApp(PersistenceService(store: .named(store, reset: false)))
        await relaunched.playDaily(dayKey)
        #expect(relaunched.activeGame?.session == latest.session)
    }

    @Test func todayResumesTheLatestAttempt() async throws {
        try await expectLatestAttemptResumes(DailyKey.dayKey(for: AppClock.now))
    }

    @Test func aPastDayResumesTheLatestAttempt() async throws {
        try await expectLatestAttemptResumes(try #require(DailyKey.dayKey(DailyKey.dayKey(for: AppClock.now), addingDays: -3)))
    }

    /// TestFlight 1.0 (1) kept today's first attempt in "daily" and replays in "practice-<day>":
    /// each day keeps its most recent game.
    @Test func gamesFromBeforeTheNewRuleMoveToTheirDay() throws {
        let persistence = PersistenceService(store: .inMemory)
        let today = DailyKey.dayKey(for: AppClock.now)
        let first = GameSession(mode: .daily(dayKey: today), puzzle: TestBoards.puzzle)
        var latest = first
        _ = latest.toggleNote(4, at: TestBoards.lastEmpty)
        persistence.saveLegacyGame(first, slot: "daily", updatedAt: .now.addingTimeInterval(-60))
        persistence.saveLegacyGame(latest, slot: "practice-\(today)", updatedAt: .now)
        let reopened = PersistenceService(container: persistence.container)
        #expect(reopened.loadGame(.daily(dayKey: today)) == latest)
        #expect(reopened.dailiesInProgress == [today])
    }

    @Test func gamesOutsideTheReplayWindowAreDropped() throws {
        let persistence = PersistenceService(store: .inMemory)
        let old = try #require(DailyKey.dayKey(DailyKey.dayKey(for: AppClock.now), addingDays: -(DailyKey.replayWindow + 1)))
        persistence.saveGame(GameSession(mode: .daily(dayKey: old), puzzle: TestBoards.puzzle), in: .daily(dayKey: old))
        #expect(persistence.dailiesInProgress.contains(old))
        _ = makeApp(persistence)
        #expect(!persistence.dailiesInProgress.contains(old))
    }

    @Test func todayCanBeReplayedAndKeepsTheBest() throws {
        let app = makeApp()
        let today = app.todayKey
        let best = win(app, today, seconds: 200)
        #expect(app.persistence.dailies[today]?.score == best)
        // A worse attempt doesn't replace it; it's still one completed daily.
        win(app, today, seconds: 200, mistakes: 2)
        #expect(app.persistence.dailies[today]?.score == best)
        #expect(app.progress.dailiesCompleted == 1)
        // The same score, faster, keeps the faster time.
        #expect(win(app, today, seconds: 100) == best)
        #expect(app.persistence.dailies[today]?.seconds == 100)
        #expect(app.activeKind == .daily(dayKey: today, isReplay: true))
    }

    @Test func aPastDayKeepsItsBestScore() throws {
        let app = makeApp()
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: -4))
        let worse = win(app, day, mistakes: 3)
        #expect(app.persistence.dailies[day]?.score == worse)
        let better = win(app, day)
        #expect(better > worse)
        #expect(app.persistence.dailies[day]?.score == better)
        #expect(app.progress.lateDays == [day])
    }

    @Test func winningAMissedDayFillsTheStreakOnce() throws {
        let app = makeApp()
        let today = app.todayKey
        let yesterday = try #require(DailyKey.dayKey(today, addingDays: -1))
        let before = try #require(DailyKey.dayKey(today, addingDays: -2))
        win(app, before)
        win(app, today)
        #expect(app.currentStreak == 1)
        win(app, yesterday)
        #expect(app.persistence.dailies[yesterday]?.isCompleted == true)
        #expect(app.currentStreak == 3)
        #expect(app.progress.dailiesCompleted == 3)
        #expect(app.progress.lateDays == [yesterday, before])
        #expect(!app.daysInProgress.contains(yesterday))
        // Winning it again doesn't count twice.
        win(app, yesterday)
        #expect(app.progress.dailiesCompleted == 3)
    }

    @Test func hintsCostTenInEveryDaily() async throws {
        let app = makeApp()
        app.record(.scoreChanged(-1))
        #expect(app.progress.unlocked.contains(.inTheRed))
        #expect(app.classicScoring == .cheapHints)
        let yesterday = try #require(DailyKey.dayKey(app.todayKey, addingDays: -1))
        await app.playDaily(yesterday)
        #expect(app.activeGame?.session.scoring == .standard)
        app.restart()
        #expect(app.activeGame?.session.scoring == .standard)
    }

    @Test func winningTheDailyKeepsItsTime() {
        let app = makeApp()
        let today = app.todayKey
        win(app, today, seconds: 42)
        #expect(app.persistence.dailies[today]?.isCompleted == true)
        #expect(app.persistence.dailies[today]?.seconds == 42)
        #expect(GameCenterService.dailyContext(seconds: 42) == 43)
    }

    @Test func sameScoreGoesToTheFasterTime() {
        typealias Entry = GameCenterService.Entry
        func entry(_ id: String, _ rank: Int, _ score: Int, _ seconds: Int?) -> Entry {
            Entry(id: id, rank: rank, name: id, score: score, isLocalPlayer: id == "me",
                  context: GameCenterService.dailyContext(seconds: seconds))
        }
        let ranked = GameCenterService.rankedByScoreAndTime([
            entry("slow", 1, 900, 400), entry("none", 2, 900, nil), entry("me", 3, 900, 200),
            entry("tie", 4, 900, 200), entry("low", 5, 700, 100),
        ])
        #expect(ranked.map(\.id) == ["me", "tie", "slow", "none", "low"])
        #expect(ranked.map(\.rank) == [1, 1, 3, 4, 5])
        #expect(GameCenterService.dailySeconds(of: ranked[0]) == 200)
    }

    @Test func fasterOfTwoEqualResultsWins() {
        let slow = DailyRecord(score: 900, isFinished: true, isCompleted: true, seconds: 300)
        let fast = DailyRecord(score: 900, isFinished: true, isCompleted: true, seconds: 200)
        #expect(slow.better(than: fast) == fast)
        #expect(fast.better(than: slow) == fast)
    }
}
