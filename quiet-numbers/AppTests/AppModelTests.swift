import QuietCore
import Foundation
import QuietNumbersCore
import QuietUI
import Testing
@testable import Quiet_Numbers

@MainActor
@Suite struct AppModelTests {
    private func makeApp() -> AppModel {
        AppModel(persistence: PersistenceService(store: .inMemory))
    }

    @Test func firstDailyOfTheDayIsScoredAndSaved() {
        let app = makeApp()
        let today = app.todayKey
        #expect(app.isScored(today))
        app.playDaily(today)
        #expect(app.activeKind == .daily(dayKey: today))
        #expect(app.isDailyInProgress(today))
        #expect(app.persistence.dailies[today] != nil)
    }

    @Test func dailyResumesWhileInProgress() {
        let app = makeApp()
        let today = app.todayKey
        app.playDaily(today)
        let first = app.activeGame
        app.playDaily(today)
        #expect(app.activeKind == .daily(dayKey: today))
        #expect(app.activeGame !== first)
        #expect(app.activeGame?.session == first?.session)
    }

    @Test func replayAfterFinishingIsPractice() {
        let app = makeApp()
        let today = app.todayKey
        app.persistence.finishDaily(today, score: 120, isCompleted: true)
        #expect(!app.isScored(today))
        app.playDaily(today)
        #expect(app.activeKind == .practice(dayKey: today))
    }

    @Test func pastDaysArePractice() throws {
        let app = makeApp()
        let yesterday = try #require(DailyKey.dayKey(app.todayKey, addingDays: -1))
        app.playDaily(yesterday)
        #expect(app.activeKind == .practice(dayKey: yesterday))
        #expect(app.persistence.dailies[yesterday] == nil)
    }

    @Test func streakCountsCompletedDaysOnly() throws {
        let app = makeApp()
        let today = app.todayKey
        let yesterday = try #require(DailyKey.dayKey(today, addingDays: -1))
        app.persistence.finishDaily(yesterday, score: 50, isCompleted: true)
        #expect(app.currentStreak == 1)
        app.persistence.finishDaily(today, score: 10, isCompleted: false)
        #expect(app.currentStreak == 1)
        app.persistence.finishDaily(today, score: 90, isCompleted: true)
        #expect(app.currentStreak == 2)
    }

    @Test func classicGameIsSavedAndRestored() {
        let app = makeApp()
        app.newClassic()
        app.activeGame?.addNumbers()
        app.sessionChanged()
        let saved = app.activeGame?.session
        #expect(app.hasClassicInProgress)
        app.continueClassic()
        #expect(app.activeGame?.session == saved)
    }
}

@MainActor
@Suite struct AchievementWiringTests {
    @Test func unlocksAreAnnouncedAndPersisted() {
        let persistence = PersistenceService(store: .inMemory)
        let app = AppModel(persistence: persistence)
        app.record(.gameFinished(classicScore: nil))
        #expect(app.pendingUnlocks == [.firstStep])
        app.dismissUnlock(.firstStep)
        #expect(app.pendingUnlocks.isEmpty)
        #expect(AppModel(persistence: persistence).progress.unlocked == [.firstStep])
    }

    @Test func gameEventsReachProgress() {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        let model = GameModel(session: GameSession(values: [4, 4, 1, 2, 1, 2, 1, 2, 1], seed: 0))
        app.start(model, as: .practice(dayKey: app.todayKey))
        model.tap(model.session.board.cells[0])
        model.tap(model.session.board.cells[1])
        #expect(model.session.score == 1)
        #expect(app.progress.equalPairsRun == 1)
    }

    @Test func newGameKeepsTheAbandonedScoreAsBest() throws {
        let persistence = PersistenceService(store: .inMemory)
        let app = AppModel(persistence: persistence)
        app.newClassic()
        let first = try #require(app.activeGame)
        var session = first.session
        while session.score < 5, let pair = MatchRules.validPairs(on: session.board).first {
            _ = session.match(at: pair.first, pair.second)
        }
        persistence.saveGame(session, in: .classic)
        app.newClassic()
        #expect(app.progress.bestScore == session.score)
        #expect(app.progress.bestScore > 0)
        #expect(app.progress.gamesFinished == 0)
        #expect(app.progress.gamesPlayed == 1)
    }

    @Test func inTheRedMakesHintsCheaperOnlyInClassic() throws {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        app.newClassic()
        #expect(try #require(app.activeGame).session.scoring.hintCost == 10)
        app.record(.hintUsed(scoreAfter: -10))
        app.newClassic()
        #expect(try #require(app.activeGame).session.scoring.hintCost == 3)
        app.playDaily(app.todayKey)
        #expect(try #require(app.activeGame).session.scoring.hintCost == 10)
        // A past day replayed as practice is still a daily challenge.
        let past = try #require(DailyKey.dayKey(app.todayKey, addingDays: -2))
        app.playDaily(past)
        #expect(app.activeKind == .practice(dayKey: past))
        #expect(try #require(app.activeGame).session.scoring.hintCost == 10)
    }

    @Test func clearedPracticeMarksAndFillsTheDay() {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        let day = "2026-10-01"
        let model = GameModel(session: GameSession(values: [4, 4], mode: .daily(dayKey: day), seed: 0))
        app.start(model, as: .practice(dayKey: day))
        model.tap(model.session.board.cells[0])
        model.tap(model.session.board.cells[1])
        app.sessionChanged()
        #expect(model.session.isCompleted)
        #expect(app.progress.practicedDays == [day])
        #expect(app.persistence.dailies[day]?.isCompleted == true)
        #expect(app.longestStreak == 1)
    }

    @Test func practiceIsSavedAndResumed() throws {
        let persistence = PersistenceService(store: .inMemory)
        let app = AppModel(persistence: persistence)
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: -3))
        app.playDaily(day)
        let game = try #require(app.activeGame)
        let pair = try #require(MatchRules.validPairs(on: game.session.board).first)
        let cells = game.session.board.cells
        game.tap(cells[pair.first])
        game.tap(cells[pair.second])
        app.sessionChanged()
        #expect(app.daysInProgress == [day])

        // Leaving and coming back (even after relaunching) continues the same game.
        let played = game.session
        app.playDaily(day)
        #expect(app.activeGame?.session == played)
        #expect(AppModel(persistence: persistence).daysInProgress == [day])
        // Today's scored attempt stays separate.
        #expect(persistence.dailies[day] == nil)
    }

    @Test func finishedPracticeIsDropped() {
        let persistence = PersistenceService(store: .inMemory)
        let app = AppModel(persistence: persistence)
        let day = "2026-10-01"
        let model = GameModel(session: GameSession(values: [4, 4], mode: .daily(dayKey: day), seed: 0))
        app.start(model, as: .practice(dayKey: day))
        persistence.saveGame(model.session, in: .practice(dayKey: day))
        model.tap(model.session.board.cells[0])
        model.tap(model.session.board.cells[1])
        app.sessionChanged()
        #expect(persistence.practiceInProgress.isEmpty)
    }

    @Test func practiceOutsideTheReplayWindowIsDropped() {
        let persistence = PersistenceService(store: .inMemory)
        let session = DailyChallenge.session(forDayKey: "2026-08-01")
        persistence.saveGame(session, in: .practice(dayKey: "2026-08-01"))
        persistence.saveGame(session, in: .practice(dayKey: "2026-10-20"))
        persistence.deletePractice(before: "2026-09-27")
        #expect(persistence.practiceInProgress == ["2026-10-20"])
    }

    @Test func reachingTheGoalCompletesTheDayOnce() {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        let today = app.todayKey
        let board = Board(values: [4, 4, 1, 2, 1, 2, 1, 2, 1, 3, 7, 2, 1, 2, 1, 2, 1, 2])
        let model = GameModel(session: GameSession(board: board, mode: .daily(dayKey: today), score: 399, goal: 400))
        app.start(model, as: .daily(dayKey: today))
        model.tap(model.session.board.cells[0])
        model.tap(model.session.board.cells[1])
        app.sessionChanged()
        // The goal ends the game: the day is completed and closed at that score.
        #expect(model.session.isCompleted && model.session.isOver)
        #expect(app.persistence.dailies[today]?.isCompleted == true)
        #expect(app.persistence.dailies[today]?.isFinished == true)
        #expect(app.persistence.dailies[today]?.score == 400)
        #expect(app.currentStreak == 1)
        #expect(app.progress.dailiesCompleted == 1)
        #expect(!app.isDailyInProgress(today))
        #expect(app.unlockedThisGame.contains(.firstStep))
        #expect(app.pendingUnlocks.isEmpty)
    }

    @Test func aDailySavedPastItsGoalIsClosedOnLaunch() throws {
        let persistence = PersistenceService(store: .inMemory)
        let today = DailyKey.dayKey(for: AppClock.now)
        var session = GameSession(board: Board(values: [4, 4, 1, 2, 1, 2, 1, 2, 3, 7]), mode: .daily(dayKey: today), score: 399, goal: 400)
        _ = session.match(at: 0, 1)
        persistence.startDaily(today)
        persistence.saveGame(session, in: .daily)
        let app = AppModel(persistence: persistence)
        #expect(!app.isDailyInProgress(today))
        #expect(persistence.loadGame(.daily) == nil)
        #expect(persistence.dailies[today]?.isFinished == true)
        #expect(persistence.dailies[today]?.isCompleted == true)
    }

    @Test func startingOverAPracticeDealsTheDayAgain() throws {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: -3))
        app.playDaily(day)
        let game = try #require(app.activeGame)
        let pair = try #require(MatchRules.validPairs(on: game.session.board).first)
        game.tap(game.session.board.cells[pair.first])
        game.tap(game.session.board.cells[pair.second])
        app.sessionChanged()
        #expect(app.daysInProgress.contains(day))
        app.discardPractice(day)
        #expect(!app.daysInProgress.contains(day))
        app.playDaily(day)
        #expect(app.activeGame?.session.score == 0)
    }

    @Test func newBestShowsDuringTheGame() throws {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        app.newClassic()
        let game = try #require(app.activeGame)
        let pair = try #require(MatchRules.validPairs(on: game.session.board).first)
        let cells = game.session.board.cells
        game.tap(cells[pair.first])
        game.tap(cells[pair.second])
        app.sessionChanged()
        #expect(app.progress.bestScore == game.session.score)
        #expect(app.progress.bestScore > 0)
    }

    @Test func resetErasesProgressGamesAndDailies() {
        let persistence = PersistenceService(store: .inMemory)
        let app = AppModel(persistence: persistence)
        app.record(.gameFinished(classicScore: 300))
        app.newClassic()
        persistence.finishDaily("2026-10-20", score: 120, isCompleted: true)
        UserDefaults.standard.set(ThemeChoice.sageSand.rawValue, forKey: PreferenceKey.theme)

        app.resetProgress()

        #expect(app.progress == PlayerProgress())
        #expect(app.activeGame == nil)
        #expect(!app.hasClassicInProgress)
        #expect(persistence.dailies.isEmpty)
        #expect(UserDefaults.standard.string(forKey: PreferenceKey.theme) == nil)
        // Signed out: the cloud copy is cleared on the next sign-in.
        #expect(UserDefaults.standard.bool(forKey: PreferenceKey.pendingCloudReset))
        UserDefaults.standard.removeObject(forKey: PreferenceKey.pendingCloudReset)
        #expect(AppModel(persistence: persistence).progress == PlayerProgress())
    }

    @Test func lockedRewardsNeedTheirAchievement() {
        let progress = PlayerProgress(unlocked: [.noHelp])
        #expect(ThemeChoice.tealCoral.isUnlocked(in: progress))
        #expect(ThemeChoice.sageSand.isUnlocked(in: progress))
        #expect(!ThemeChoice.sageCoral.isUnlocked(in: progress))
        #expect(ThemeChoice.highContrast.isUnlocked(in: PlayerProgress()))
    }

    @Test func legacyThemeIDsMigrate() {
        let defaults = UserDefaults(suiteName: "legacyThemeIDsMigrate")!
        for (old, new) in [("paper", ThemeChoice.tealCoral), ("midnight", .sageCoral), ("ember", .highContrast)] {
            defaults.set(old, forKey: PreferenceKey.theme)
            ThemeChoice.migrateSavedChoice(in: defaults)
            #expect(defaults.string(forKey: PreferenceKey.theme) == new.rawValue)
        }
        ThemeChoice.migrateSavedChoice(in: defaults)
        #expect(defaults.string(forKey: PreferenceKey.theme) == ThemeChoice.highContrast.rawValue)
        defaults.removePersistentDomain(forName: "legacyThemeIDsMigrate")
    }
}

@MainActor
@Suite struct SyncMergeTests {
    @Test func betterDailyResultWins() {
        let started = DailyRecord(score: 0, isFinished: false, isCompleted: false)
        let played = DailyRecord(score: 80, isFinished: true, isCompleted: false)
        let completed = DailyRecord(score: 40, isFinished: true, isCompleted: true)
        #expect(played.better(than: started) == played)
        #expect(played.better(than: completed) == completed)
        #expect(completed.better(than: DailyRecord(score: 60, isFinished: true, isCompleted: true)).score == 60)
    }

    @Test func remoteDailiesMergeIntoLocalStore() {
        let persistence = PersistenceService(store: .inMemory)
        persistence.finishDaily("2026-10-20", score: 30, isCompleted: false)
        persistence.finishDaily("2026-10-21", score: 90, isCompleted: true)
        persistence.mergeDailies([
            "2026-10-20": DailyRecord(score: 70, isFinished: true, isCompleted: true),
            "2026-10-21": DailyRecord(score: 10, isFinished: true, isCompleted: false),
            "2026-10-22": DailyRecord(score: 55, isFinished: true, isCompleted: true),
        ])
        #expect(persistence.dailies["2026-10-20"]?.score == 70)
        #expect(persistence.dailies["2026-10-21"]?.score == 90)
        #expect(persistence.completedDays == ["2026-10-20", "2026-10-21", "2026-10-22"])
    }
}

@MainActor
@Suite struct DailyTieBreakTests {
    private typealias Entry = GameCenterService.Entry

    private func entry(_ id: String, rank: Int, score: Int, seconds: Int?) -> Entry {
        Entry(id: id, rank: rank, name: id, score: score, isLocalPlayer: id == "me", context: seconds.map { $0 + 1 } ?? 0)
    }

    @Test func sameScoreGoesToTheFasterTime() {
        let ranked = GameCenterService.rankedByScoreAndTime([
            entry("slow", rank: 1, score: 500, seconds: 300),
            entry("fast", rank: 1, score: 500, seconds: 120),
            entry("old", rank: 1, score: 500, seconds: nil),
            entry("top", rank: 1, score: 520, seconds: 900),
            entry("twin", rank: 5, score: 500, seconds: 120),
        ])
        #expect(ranked.map(\.id) == ["top", "fast", "twin", "slow", "old"])
        #expect(ranked.map(\.rank) == [1, 2, 2, 4, 5])
        #expect(GameCenterService.dailySeconds(of: ranked[1]) == 120)
        #expect(GameCenterService.dailySeconds(of: ranked[4]) == nil)
    }

    @Test func finishingADailyKeepsItsTime() throws {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        let today = app.todayKey
        let model = GameModel(session: GameSession(board: Board(values: [4, 4, 1, 2, 1, 2, 1, 2, 3, 7]), mode: .daily(dayKey: today), score: 0, goal: 2))
        app.start(model, as: .daily(dayKey: today))
        model.tap(model.session.board.cells[0])
        model.tap(model.session.board.cells[1])
        for _ in 0..<42 { model.tick() }
        model.tap(model.session.board.cells[8])
        model.tap(model.session.board.cells[9])
        app.sessionChanged()
        #expect(app.persistence.dailies[today]?.isFinished == true)
        #expect(app.persistence.dailies[today]?.seconds == 42)
    }

    @Test func theFasterOfTwoEqualResultsWins() {
        let slow = DailyRecord(score: 500, isFinished: true, isCompleted: true, seconds: 300)
        let fast = DailyRecord(score: 500, isFinished: true, isCompleted: true, seconds: 200)
        let old = DailyRecord(score: 500, isFinished: true, isCompleted: true)
        #expect(slow.better(than: fast) == fast)
        #expect(old.better(than: slow) == slow)
    }
}

@MainActor
@Suite struct FilledDayTests {
    /// Completes `dayKey` as practice on a board that reaches a goal of 2 in two moves.
    private func completePractice(_ app: AppModel, _ dayKey: String) {
        let model = GameModel(session: GameSession(board: Board(values: [4, 4, 1, 2, 1, 2, 1, 2, 3, 7]), mode: .daily(dayKey: dayKey), score: 0, goal: 2))
        app.start(model, as: .practice(dayKey: dayKey))
        model.tap(model.session.board.cells[0])
        model.tap(model.session.board.cells[1])
        model.tap(model.session.board.cells[8])
        model.tap(model.session.board.cells[9])
        app.sessionChanged()
    }

    @Test func completingAMissedDayFillsTheStreak() throws {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        let today = app.todayKey
        let yesterday = try #require(DailyKey.dayKey(today, addingDays: -1))
        let before = try #require(DailyKey.dayKey(today, addingDays: -2))
        app.persistence.finishDaily(before, score: 500, isCompleted: true)
        app.persistence.finishDaily(today, score: 450, isCompleted: true)
        #expect(app.currentStreak == 1)
        completePractice(app, yesterday)
        #expect(app.persistence.dailies[yesterday]?.isCompleted == true)
        #expect(app.currentStreak == 3)
        #expect(app.progress.dailiesCompleted == 1)
        // Doing it again doesn't count twice.
        completePractice(app, yesterday)
        #expect(app.progress.dailiesCompleted == 1)
    }

    @Test func aFailedDayKeepsItsScoredResult() throws {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        let day = try #require(DailyKey.dayKey(app.todayKey, addingDays: -4))
        app.persistence.finishDaily(day, score: 310, isCompleted: false)
        completePractice(app, day)
        #expect(app.persistence.dailies[day]?.isCompleted == true)
        #expect(app.persistence.dailies[day]?.score == 310)
    }
}
