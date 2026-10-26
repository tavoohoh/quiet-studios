import Testing
@testable import QuietNumbersCore

@Suite struct AchievementsTests {
    private func outcome(
        values: [Int] = [3, 7],
        rows: [Int] = [],
        boardCleared: Bool = false,
        withoutHelp: Bool = false,
        stage: Int = 1
    ) -> MatchOutcome {
        MatchOutcome(
            pair: Pair(0, 1, gap: 0),
            points: 1,
            values: values,
            clearedRows: rows,
            boardCleared: boardCleared,
            clearedWithoutHelp: withoutHelp,
            stage: stage
        )
    }

    @Test func firstGameUnlocksFirstStep() {
        var progress = PlayerProgress()
        #expect(progress.record(.gameFinished) == [.firstStep])
        #expect(progress.record(.gameFinished).isEmpty)
    }

    @Test func clearingBoardWithoutHelpUnlocksBoth() {
        var progress = PlayerProgress()
        let unlocked = progress.record(.matched(outcome(boardCleared: true, withoutHelp: true, stage: 2)))
        #expect(Set(unlocked) == [.cleanSlate, .noHelp])
    }

    @Test func clearingBoardWithHelpOnlyUnlocksCleanSlate() {
        var progress = PlayerProgress()
        #expect(progress.record(.matched(outcome(boardCleared: true, stage: 2))) == [.cleanSlate])
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

    @Test func streakAndNightOwl() {
        var progress = PlayerProgress()
        #expect(Set(progress.record(.dailyCompleted(currentStreak: 7, localHour: 2))) == [.consistency, .nightOwl])
        #expect(progress.record(.dailyCompleted(currentStreak: 30, localHour: 12)) == [.habit])
        #expect(progress.progress(of: .centennial) == 0.02)
    }
}
