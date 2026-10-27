import Foundation
import Testing
@testable import QuietNumbersCore

@Suite struct AchievementsTests {
    private func outcome(
        values: [Int] = [3, 7],
        rows: [Int] = [],
        boardCleared: Bool = false,
        stage: Int = 1,
        hintsOnBoard: Int = 0,
        usedPlusOnBoard: Bool = false
    ) -> MatchOutcome {
        MatchOutcome(
            pair: Pair(0, 1, gap: 0),
            points: 1,
            values: values,
            clearedRows: rows,
            clearedDigits: [],
            boardCleared: boardCleared,
            stage: stage,
            hintsOnBoard: hintsOnBoard,
            usedPlusOnBoard: usedPlusOnBoard
        )
    }

    @Test func firstGameUnlocksFirstStep() {
        var progress = PlayerProgress()
        #expect(progress.record(.gameFinished(classicScore: nil)) == [.firstStep])
        #expect(progress.record(.gameFinished(classicScore: nil)).isEmpty)
    }

    @Test func firstClearedBoardAlsoUnlocksFirstStep() {
        var progress = PlayerProgress()
        let unlocked = progress.record(.matched(outcome(boardCleared: true, stage: 2, hintsOnBoard: 1, usedPlusOnBoard: true)))
        #expect(unlocked == [.firstStep])
    }

    @Test func bestScoreTracksClassicGamesOnly() {
        var progress = PlayerProgress()
        _ = progress.record(.gameFinished(classicScore: 320))
        _ = progress.record(.gameFinished(classicScore: 150))
        _ = progress.record(.gameFinished(classicScore: nil))
        #expect(progress.bestScore == 320)
    }

    @Test func mergeKeepsEverythingEarnedOnEitherDevice() {
        var phone = PlayerProgress()
        _ = phone.record(.gameFinished(classicScore: 500))
        _ = phone.record(.matched(outcome(rows: [0, 1, 2])))
        var mac = PlayerProgress()
        _ = mac.record(.matched(outcome(boardCleared: true, stage: 2)))
        _ = mac.record(.gameFinished(classicScore: 900))
        _ = mac.record(.classicAbandoned(score: 100, played: true))

        let merged = phone.merged(with: mac)
        #expect(merged.unlocked == [.firstStep, .cleanSlate, .noHelp])
        #expect(merged.bestScore == 900)
        #expect(merged.rowsCleared == 3)
        #expect(merged.gamesPlayed == 2)
        #expect(merged == mac.merged(with: phone))
    }

    @Test func clearingBoardWithoutPlusUnlocksCleanSlate() {
        var progress = PlayerProgress()
        _ = progress.record(.matched(outcome(boardCleared: true, stage: 2, hintsOnBoard: 1, usedPlusOnBoard: true)))
        #expect(progress.record(.matched(outcome(boardCleared: true, stage: 3, hintsOnBoard: 1))) == [.cleanSlate])
    }

    @Test func clearingBoardWithoutHintsUnlocksNoHelp() {
        var progress = PlayerProgress()
        _ = progress.record(.gameFinished(classicScore: 40))
        #expect(progress.record(.matched(outcome(boardCleared: true, stage: 2, usedPlusOnBoard: true))) == [.noHelp])
    }

    @Test func goingNegativeUnlocksInTheRed() {
        var progress = PlayerProgress()
        #expect(progress.record(.hintUsed(scoreAfter: 0)).isEmpty)
        #expect(progress.record(.hintUsed(scoreAfter: -3)) == [.inTheRed])
    }

    @Test func abandonedClassicGameStillSetsBest() {
        var progress = PlayerProgress()
        _ = progress.record(.classicAbandoned(score: 210, played: true))
        _ = progress.record(.classicAbandoned(score: 0, played: false))
        #expect(progress.bestScore == 210)
        #expect(progress.gamesFinished == 0)
        #expect(progress.gamesPlayed == 1)
    }

    @Test func liveClassicScoreRaisesTheBest() {
        var progress = PlayerProgress()
        _ = progress.record(.classicScore(120))
        _ = progress.record(.classicScore(80))
        #expect(progress.bestScore == 120)
        #expect(progress.gamesPlayed == 0)
    }

    @Test func progressSavedBeforeGamesPlayedStillLoads() throws {
        var progress = PlayerProgress()
        _ = progress.record(.gameFinished(classicScore: 10))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(progress)) as! [String: Any]
        json["gamesPlayedCount"] = nil
        let old = try JSONDecoder().decode(PlayerProgress.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.gamesPlayed == 1)
    }

    @Test func practiceMarksTheDayAndNothingElse() throws {
        var progress = PlayerProgress()
        let unlocked = progress.record(.practiceCompleted(dayKey: "2026-10-01"))
        #expect(unlocked.isEmpty)
        #expect(progress.practicedDays == ["2026-10-01"])
        #expect(progress.dailiesCompleted == 0 && progress.bestStreak == 0)

        var other = PlayerProgress()
        _ = other.record(.practiceCompleted(dayKey: "2026-10-02"))
        #expect(progress.merged(with: other).practicedDays == ["2026-10-01", "2026-10-02"])

        // Progress saved before practice days existed still loads.
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(progress)) as! [String: Any]
        json["practicedDayKeys"] = nil
        let old = try JSONDecoder().decode(PlayerProgress.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.practicedDays.isEmpty)
    }

    @Test func sweeperNeeds100Rows() {
        var progress = PlayerProgress()
        for _ in 0..<49 { _ = progress.record(.matched(outcome(rows: [0, 1]))) }
        #expect(progress.progress(of: .sweeper) == 0.98)
        #expect(progress.record(.matched(outcome(rows: [3, 4]))) == [.sweeper])
    }

    @Test func reachingStageFive() {
        var progress = PlayerProgress()
        #expect(progress.record(.matched(outcome(stage: 4))).isEmpty)
        #expect(progress.record(.matched(outcome(stage: 5))) == [.stageFive])
    }

    @Test func monotoneNeedsTenEqualPairsInARow() {
        var progress = PlayerProgress()
        for _ in 0..<9 { _ = progress.record(.matched(outcome(values: [4, 4]))) }
        _ = progress.record(.matched(outcome(values: [3, 7])))
        for _ in 0..<9 { _ = progress.record(.matched(outcome(values: [6, 6]))) }
        #expect(!progress.unlocked.contains(.monotone))
        #expect(progress.record(.matched(outcome(values: [6, 6]))) == [.monotone])
    }

    @Test func undoTakesCountersBack() {
        var progress = PlayerProgress()
        let match = outcome(values: [4, 4], rows: [0])
        _ = progress.record(.matched(match))
        _ = progress.record(.undone(match))
        #expect(progress.rowsCleared == 0)
        #expect(progress.equalPairsRun == 0)
    }

    @Test func streakAndNightOwl() {
        var progress = PlayerProgress()
        #expect(Set(progress.record(.dailyCompleted(currentStreak: 7, localHour: 2))) == [.consistency, .nightOwl])
        #expect(progress.record(.dailyCompleted(currentStreak: 30, localHour: 12)) == [.habit])
        #expect(progress.progress(of: .centennial) == 0.02)
    }
}
