import Testing
@testable import QuietNumbersCore

@Suite struct AchievementsTests {
    private func outcome(
        values: [Int] = [3, 7],
        rows: [Int] = [],
        boardCleared: Bool = false,
        stage: Int = 1
    ) -> MatchOutcome {
        MatchOutcome(
            pair: Pair(0, 1, gap: 0),
            points: 1,
            values: values,
            clearedRows: rows,
            clearedDigits: [],
            boardCleared: boardCleared,
            stage: stage
        )
    }

    @Test func firstGameUnlocksFirstStep() {
        var progress = PlayerProgress()
        #expect(progress.record(.gameFinished(classicScore: nil, hintsUsed: 1)) == [.firstStep])
        #expect(progress.record(.gameFinished(classicScore: nil, hintsUsed: 1)).isEmpty)
    }

    @Test func bestScoreTracksClassicGamesOnly() {
        var progress = PlayerProgress()
        _ = progress.record(.gameFinished(classicScore: 320, hintsUsed: 1))
        _ = progress.record(.gameFinished(classicScore: 150, hintsUsed: 1))
        _ = progress.record(.gameFinished(classicScore: nil, hintsUsed: 1))
        #expect(progress.bestScore == 320)
    }

    @Test func mergeKeepsEverythingEarnedOnEitherDevice() {
        var phone = PlayerProgress()
        _ = phone.record(.gameFinished(classicScore: 500, hintsUsed: 1))
        _ = phone.record(.matched(outcome(rows: [0, 1, 2])))
        var mac = PlayerProgress()
        _ = mac.record(.matched(outcome(boardCleared: true, stage: 2)))
        _ = mac.record(.gameFinished(classicScore: 900, hintsUsed: 0))

        let merged = phone.merged(with: mac)
        #expect(merged.unlocked == [.firstStep, .cleanSlate, .noHelp])
        #expect(merged.bestScore == 900)
        #expect(merged.rowsCleared == 3)
        #expect(merged == mac.merged(with: phone))
    }

    @Test func clearingBoardUnlocksCleanSlate() {
        var progress = PlayerProgress()
        #expect(progress.record(.matched(outcome(boardCleared: true, stage: 2))) == [.cleanSlate])
    }

    @Test func finishingWithoutHintsUnlocksNoHelp() {
        var progress = PlayerProgress()
        #expect(Set(progress.record(.gameFinished(classicScore: 40, hintsUsed: 0))) == [.firstStep, .noHelp])
    }

    @Test func goingNegativeUnlocksInTheRed() {
        var progress = PlayerProgress()
        #expect(progress.record(.hintUsed(scoreAfter: 0)).isEmpty)
        #expect(progress.record(.hintUsed(scoreAfter: -3)) == [.inTheRed])
    }

    @Test func abandonedClassicGameStillSetsBest() {
        var progress = PlayerProgress()
        _ = progress.record(.classicAbandoned(score: 210))
        _ = progress.record(.classicAbandoned(score: 90))
        #expect(progress.bestScore == 210)
        #expect(progress.gamesFinished == 0)
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
