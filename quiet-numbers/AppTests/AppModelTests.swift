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
