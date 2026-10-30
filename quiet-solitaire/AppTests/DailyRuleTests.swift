import Foundation
import QuietCore
import QuietSolitaireCore
import QuietUI
import Testing
@testable import Quiet_Solitaire

/// The family's daily rule (root CLAUDE.md, "Reto diario"), as Quiet Solitaire plays it.
@MainActor
@Suite struct DailyRuleTests {
    private func makeApp(_ persistence: PersistenceService = PersistenceService(store: .inMemory)) -> AppModel {
        AppModel(persistence: persistence)
    }

    /// A table one move from the win: K♠ on the waste, everything else on the foundations.
    private func oneMoveFromWin(_ mode: GameSession.Mode, seconds: Int = 0) -> GameModel {
        let foundations = Suit.allCases.map { suit in (1...(suit == .spades ? 12 : 13)).map { Card($0, suit) } }
        let state = GameState(stock: [], waste: [Card(13, .spades)], foundations: foundations, tableau: Array(repeating: [], count: 7))
        return GameModel(session: GameSession(mode: mode, state: state, elapsedSeconds: seconds))
    }

    private func winPractice(_ app: AppModel, _ dayKey: String) {
        let model = oneMoveFromWin(.daily(dayKey: dayKey))
        app.start(model, as: .practice(dayKey: dayKey))
        model.tap(Card(13, .spades).id)
    }

    @Test func firstDailyOfTheDayIsScored() async {
        let app = makeApp()
        let today = app.todayKey
        await app.playDaily(today)
        #expect(app.activeKind == .daily(dayKey: today))
        #expect(app.isDailyInProgress(today))
    }

    @Test func practiceIsSavedAndResumed() async throws {
        let app = makeApp()
        let yesterday = try #require(DailyKey.dayKey(app.todayKey, addingDays: -1))
        await app.playDaily(yesterday)
        #expect(app.activeKind == .practice(dayKey: yesterday))
        let game = try #require(app.activeGame)
        game.drawFromStock()
        #expect(app.persistence.practiceInProgress.contains(yesterday))
        #expect(app.daysInProgress.contains(yesterday))
        // Back to the same day: the same game, not a new deal.
        await app.playDaily(yesterday)
        #expect(app.activeGame !== game)
        #expect(app.activeGame?.session == game.session)
        #expect(app.persistence.dailies[yesterday] == nil)
    }

    @Test func startingOverAPracticeDealsTheDayAgain() async throws {
        let app = makeApp()
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: -2))
        await app.playDaily(day)
        app.activeGame?.drawFromStock()
        app.discardPractice(day)
        #expect(!app.persistence.practiceInProgress.contains(day))
        await app.playDaily(day)
        #expect(app.activeGame?.session.moves == 0)
    }

    @Test func practiceOutsideTheReplayWindowIsDropped() throws {
        let persistence = PersistenceService(store: .inMemory)
        let old = try #require(DailyKey.dayKey(DailyKey.dayKey(for: AppClock.now), addingDays: -(DailyKey.replayWindow + 1)))
        persistence.saveGame(GameSession(mode: .daily(dayKey: old), seed: 1), in: .practice(dayKey: old))
        #expect(persistence.practiceInProgress.contains(old))
        _ = makeApp(persistence)
        #expect(!persistence.practiceInProgress.contains(old))
    }

    @Test func winningAMissedDayFillsTheStreakOnce() throws {
        let app = makeApp()
        let today = app.todayKey
        let yesterday = try #require(DailyKey.dayKey(today, addingDays: -1))
        let before = try #require(DailyKey.dayKey(today, addingDays: -2))
        app.persistence.finishDaily(before, score: 500, isCompleted: true)
        app.persistence.finishDaily(today, score: 450, isCompleted: true)
        #expect(app.currentStreak == 1)
        winPractice(app, yesterday)
        #expect(app.persistence.dailies[yesterday]?.isCompleted == true)
        #expect(app.currentStreak == 3)
        #expect(app.progress.dailiesCompleted == 1)
        #expect(app.progress.practicedDays.contains(yesterday))
        #expect(!app.persistence.practiceInProgress.contains(yesterday))
        // Winning it again doesn't count twice.
        winPractice(app, yesterday)
        #expect(app.progress.dailiesCompleted == 1)
    }

    @Test func anUnfinishedDayKeepsItsScoredResult() throws {
        let app = makeApp()
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: -4))
        app.persistence.finishDaily(day, score: 310, isCompleted: false)
        winPractice(app, day)
        #expect(app.persistence.dailies[day]?.isCompleted == true)
        #expect(app.persistence.dailies[day]?.score == 310)
    }

    @Test func hintsCostTenInEveryDaily() async throws {
        let app = makeApp()
        app.record(.hintCharged(scoreAfter: -1))
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
        app.persistence.startDaily(today)
        let model = oneMoveFromWin(.daily(dayKey: today), seconds: 42)
        app.start(model, as: .daily(dayKey: today))
        model.tap(Card(13, .spades).id)
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
