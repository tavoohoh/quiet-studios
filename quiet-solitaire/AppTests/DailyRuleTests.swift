import Foundation
import SwiftData
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

    /// Wins `dayKey` in one move, as a new attempt.
    private func win(_ app: AppModel, _ dayKey: String, seconds: Int = 0) {
        app.persistence.startDaily(dayKey)
        let model = oneMoveFromWin(.daily(dayKey: dayKey), seconds: seconds)
        app.start(model, as: .daily(dayKey: dayKey, isReplay: app.isReplay(dayKey)))
        model.tap(Card(13, .spades).id)
    }

    @Test func firstDailyOfTheDayIsNotAReplay() async {
        let app = makeApp()
        let today = app.todayKey
        await app.playDaily(today)
        #expect(app.activeKind == .daily(dayKey: today, isReplay: false))
        #expect(app.isDailyInProgress(today))
        app.restart()
        #expect(app.activeKind == .daily(dayKey: today, isReplay: true))
    }

    /// 2026-11-02: today has no attempt limit, and every win goes to the board (its best).
    @Test func todayCanBePlayedAgainAndKeepsTheBest() {
        let app = makeApp()
        let today = app.todayKey
        win(app, today, seconds: 300)
        let first = app.persistence.dailies[today]?.score
        #expect(first != nil)
        #expect(app.progress.dailiesCompleted == 1)
        // A slower win (lower time bonus) doesn't replace it; a faster one does.
        win(app, today, seconds: 400)
        #expect(app.persistence.dailies[today]?.seconds == 300)
        win(app, today, seconds: 200)
        #expect(app.persistence.dailies[today]?.seconds == 200)
        #expect((app.persistence.dailies[today]?.score ?? 0) >= (first ?? 0))
        #expect(app.progress.dailiesCompleted == 1)
        #expect(app.isReplay(today))
    }

    @Test func aPastDayIsSavedAndResumed() async throws {
        let app = makeApp()
        let yesterday = try #require(DailyKey.dayKey(app.todayKey, addingDays: -1))
        await app.playDaily(yesterday)
        #expect(app.activeKind == .daily(dayKey: yesterday, isReplay: false))
        let game = try #require(app.activeGame)
        game.drawFromStock()
        #expect(app.daysInProgress.contains(yesterday))
        // Back to the same day: the same game, not a new deal.
        await app.playDaily(yesterday)
        #expect(app.activeGame !== game)
        #expect(app.activeGame?.session == game.session)
        #expect(app.persistence.dailies[yesterday]?.isCompleted != true)
    }

    /// Bug found in Quiet Numbers (2026-11-02): start a daily, restart it, play, leave; back
    /// in, the FIRST attempt came back. What's saved is always the attempt in progress.
    @Test(arguments: [0, -1])
    func aRestartedDailyResumesTheLatestAttempt(daysAgo: Int) async throws {
        let store = "restart-\(daysAgo)-\(UUID().uuidString)"
        let app = makeApp(PersistenceService(store: .named(store, reset: true)))
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: daysAgo))
        await app.playDaily(day)
        app.activeGame?.drawFromStock()
        app.restart()
        let latest = try #require(app.activeGame)
        latest.drawFromStock()
        latest.drawFromStock()
        app.leftGame()
        // Back to the day…
        await app.playDaily(day)
        #expect(app.activeGame?.session == latest.session)
        // …and after relaunching the app (the store on disk reopened).
        let relaunched = makeApp(PersistenceService(store: .named(store, reset: false)))
        await relaunched.playDaily(day)
        #expect(relaunched.activeGame?.session == latest.session)
    }

    @Test func startingOverDealsTheDayAgain() async throws {
        let app = makeApp()
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: -2))
        await app.playDaily(day)
        app.activeGame?.drawFromStock()
        app.discardDaily(day)
        #expect(!app.isDailyInProgress(day))
        await app.playDaily(day)
        #expect(app.activeGame?.session.moves == 0)
        #expect(app.activeKind == .daily(dayKey: day, isReplay: true))
    }

    @Test func gamesOutsideTheReplayWindowAreDropped() throws {
        let persistence = PersistenceService(store: .inMemory)
        let old = try #require(DailyKey.dayKey(DailyKey.dayKey(for: AppClock.now), addingDays: -(DailyKey.replayWindow + 1)))
        persistence.saveGame(GameSession(mode: .daily(dayKey: old), seed: 1), in: .daily(dayKey: old))
        #expect(persistence.dailiesInProgress.contains(old))
        _ = makeApp(persistence)
        #expect(!persistence.dailiesInProgress.contains(old))
    }

    /// Before 1.0 (4) today's scored attempt was in "daily" and replays in "practice-<day>".
    @Test func oldSlotsMoveToTheirDay() throws {
        let name = "migration-\(UUID().uuidString)"
        let today = DailyKey.dayKey(for: AppClock.now)
        let yesterday = try #require(DailyKey.dayKey(today, addingDays: -1))
        do {
            let old = PersistenceService(store: .named(name, reset: true))
            old.saveGame(GameSession(mode: .daily(dayKey: today), seed: 7), in: .classic)
        }
        // Rename the slots by hand, the way the old version stored them.
        let container = try ModelContainer(
            for: StoredGame.self, StoredDaily.self, StoredProgress.self,
            configurations: ModelConfiguration(url: URL.applicationSupportDirectory.appending(path: "\(name).store"), cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        let data = try JSONEncoder().encode(GameSession(mode: .daily(dayKey: yesterday), seed: 8))
        for game in try context.fetch(FetchDescriptor<StoredGame>()) { game.slot = "daily" }
        context.insert(StoredGame(slot: "practice-\(yesterday)", data: data))
        try context.save()

        let persistence = PersistenceService(store: .named(name, reset: false))
        #expect(persistence.dailiesInProgress == [today, yesterday])
        #expect(persistence.loadGame(.daily(dayKey: today))?.seed == 7)
        #expect(persistence.loadGame(.daily(dayKey: yesterday))?.seed == 8)
    }

    @Test func winningAMissedDayFillsTheStreakOnce() throws {
        let app = makeApp()
        let today = app.todayKey
        let yesterday = try #require(DailyKey.dayKey(today, addingDays: -1))
        let before = try #require(DailyKey.dayKey(today, addingDays: -2))
        app.persistence.finishDaily(before, score: 500, isCompleted: true)
        app.persistence.finishDaily(today, score: 450, isCompleted: true)
        #expect(app.currentStreak == 1)
        win(app, yesterday)
        #expect(app.persistence.dailies[yesterday]?.isCompleted == true)
        #expect(app.currentStreak == 3)
        #expect(app.progress.dailiesCompleted == 1)
        #expect(app.progress.practicedDays.contains(yesterday))
        #expect(!app.isDailyInProgress(yesterday))
        // Winning it again doesn't count twice.
        win(app, yesterday)
        #expect(app.progress.dailiesCompleted == 1)
    }

    /// A past day keeps its best score: a lower one doesn't replace it, a higher one does.
    @Test func aPastDayKeepsItsBestScore() throws {
        let app = makeApp()
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: -4))
        app.persistence.finishDaily(day, score: 99_999, isCompleted: true)
        win(app, day)
        #expect(app.persistence.dailies[day]?.score == 99_999)
        app.persistence.finishDaily(day, score: 10, isCompleted: true)
        win(app, day)
        #expect((app.persistence.dailies[day]?.score ?? 0) > 10)
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
        app.start(model, as: .daily(dayKey: today, isReplay: false))
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
