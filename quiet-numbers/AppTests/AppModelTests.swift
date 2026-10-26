import Foundation
import QuietNumbersCore
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
        let yesterday = try #require(DailyChallenge.dayKey(app.todayKey, addingDays: -1))
        app.playDaily(yesterday)
        #expect(app.activeKind == .practice(dayKey: yesterday))
        #expect(app.persistence.dailies[yesterday] == nil)
    }

    @Test func streakCountsCompletedDaysOnly() throws {
        let app = makeApp()
        let today = app.todayKey
        let yesterday = try #require(DailyChallenge.dayKey(today, addingDays: -1))
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
        app.record(.gameFinished(classicScore: nil, hintsUsed: 1))
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
    }

    @Test func resetErasesProgressGamesAndDailies() {
        let persistence = PersistenceService(store: .inMemory)
        let app = AppModel(persistence: persistence)
        app.record(.gameFinished(classicScore: 300, hintsUsed: 0))
        app.newClassic()
        persistence.finishDaily("2026-10-20", score: 120, isCompleted: true)
        UserDefaults.standard.set(ThemeChoice.slate.rawValue, forKey: PreferenceKey.theme)

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
        #expect(ThemeChoice.paper.isUnlocked(in: progress))
        #expect(ThemeChoice.slate.isUnlocked(in: progress))
        #expect(!ThemeChoice.midnight.isUnlocked(in: progress))
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
