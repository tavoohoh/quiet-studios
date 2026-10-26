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
        app.record(.gameFinished)
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

    @Test func lockedRewardsNeedTheirAchievement() {
        let progress = PlayerProgress(unlocked: [.noHelp])
        #expect(ThemeChoice.paper.isUnlocked(in: progress))
        #expect(ThemeChoice.slate.isUnlocked(in: progress))
        #expect(!ThemeChoice.midnight.isUnlocked(in: progress))
    }
}
