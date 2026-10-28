import Foundation
import QuietCore
import Testing
@testable import QuietNumbersCore

// `#expect`/`#require` can't wrap mutating calls, so results are bound first.
@Suite struct GameSessionTests {
    @Test func adjacentPairScoresOne() {
        var session = GameSession(board: makeBoard([
            [4, 4, 1, 2, 1, 2, 1, 2, 1],
            [2, 1, 2, 1, 2, 1, 2, 1, 2],
        ]))
        let outcome = session.match(at: 0, 1)
        #expect(outcome?.points == 1)
        #expect(session.score == 1)
        #expect(session.board.cells[0].isCleared && session.board.cells[1].isCleared)
    }

    @Test func pairAcrossClearedScoresFour() {
        var session = GameSession(board: makeBoard([
            [6, 0, 4, 1, 2, 1, 2, 1, 2],
            [2, 1, 2, 1, 2, 1, 2, 1, 2],
        ]))
        let outcome = session.match(at: 0, 2)
        #expect(outcome?.points == 4)
    }

    @Test func invalidMatchChangesNothing() {
        var session = GameSession(board: makeBoard([[2, 3, 1, 2, 1, 2, 1, 2, 1]]))
        let before = session
        let outcome = session.match(at: 0, 1)
        #expect(outcome == nil)
        #expect(session == before)
    }

    @Test func emptiedRowCollapsesAndScoresBonus() {
        var session = GameSession(board: makeBoard([
            [0, 0, 0, 0, 0, 0, 0, 3, 7],
            [2, 1, 2, 1, 2, 1, 2, 1, 2],
        ]), plusRemaining: 2)
        let outcome = session.match(at: 7, 8)
        #expect(outcome?.clearedRows == [0])
        #expect(outcome?.points == 1 + 10)
        #expect(session.board.rowCount == 1)
        #expect(session.board.cells.map(\.value) == [2, 1, 2, 1, 2, 1, 2, 1, 2])
        // Clearing rows doesn't give + uses back.
        #expect(session.plusRemaining == 2)
    }

    @Test func clearingTwoRowsAtOnce() {
        var session = GameSession(board: makeBoard([
            [0, 0, 0, 0, 0, 0, 0, 0, 5],
            [5, 0, 0, 0, 0, 0, 0, 0, 0],
            [2, 1, 2, 1, 2, 1, 2, 1, 2],
        ]), plusRemaining: 0)
        let outcome = session.match(at: 8, 9)
        #expect(outcome?.clearedRows == [0, 1])
        #expect(session.board.rowCount == 1)
        #expect(session.plusRemaining == 0)
    }

    @Test func middleRowCollapseKeepsColumns() {
        var session = GameSession(board: makeBoard([
            [1, 2, 1, 2, 1, 2, 1, 2, 1],
            [0, 0, 0, 0, 0, 0, 0, 4, 6],
            [9, 8, 7, 6, 5, 4, 3, 2, 1],
        ]))
        let outcome = session.match(at: 16, 17)
        #expect(outcome?.clearedRows == [1])
        #expect(session.board.cells.map(\.value) == [1, 2, 1, 2, 1, 2, 1, 2, 1, 9, 8, 7, 6, 5, 4, 3, 2, 1])
    }

    @Test func plusCopiesRemainingNumbersInOrder() {
        var session = GameSession(board: makeBoard([[1, 0, 2, 0, 3, 4, 5, 6, 7]]))
        let added = session.addNumbers()
        #expect(added)
        #expect(session.plusRemaining == GameSession.maxPlusUses - 1)
        #expect(session.board.activeValues == [1, 2, 3, 4, 5, 6, 7, 1, 2, 3, 4, 5, 6, 7])
        #expect(Set(session.board.cells.map(\.id)).count == session.board.cells.count)
    }

    @Test func plusIsLimited() {
        var session = GameSession(board: makeBoard([[1, 2, 1, 2, 1, 2, 1, 2, 1]]), plusRemaining: 0)
        let added = session.addNumbers()
        #expect(!added)
    }

    @Test func gameOverWithoutPairsOrPlus() {
        let stuck = makeBoard([[1, 2, 1, 2, 1, 2, 1, 2, 1]])
        #expect(!GameSession(board: stuck, plusRemaining: 1).isOver)
        #expect(GameSession(board: stuck, plusRemaining: 0).isOver)
        #expect(!GameSession(board: makeBoard([[1, 1, 2]]), plusRemaining: 0).isOver)
    }

    @Test func clearingBoardAdvancesStage() {
        var session = GameSession(board: makeBoard([[0, 0, 0, 0, 0, 0, 0, 2, 8]]), plusRemaining: 1)
        let outcome = session.match(at: 7, 8)
        #expect(outcome?.boardCleared == true)
        #expect(outcome?.points == 1 + 10 + 150)
        #expect(session.stage == 2)
        #expect(session.plusRemaining == GameSession.maxPlusUses)
        #expect(session.board.cells.count == BoardGenerator.initialCount(forStage: 2))
    }

    @Test func everyStageCanBeGenerated() {
        var random = SeededRandom(seed: 1)
        for stage in 1...6 {
            #expect(BoardGenerator.initialCount(forStage: stage).isMultiple(of: 2))
            #expect(BoardGenerator.makeBoard(using: &random, stage: stage).cells.count == BoardGenerator.initialCount(forStage: stage))
        }
    }

    @Test func laterStagesAreHarder() {
        #expect((1...6).map(BoardGenerator.initialCount(forStage:)) == [42, 44, 48, 50, 54, 54])
        #expect((1...6).map(GameSession.plusUses(forStage:)) == [5, 5, 4, 4, 3, 3])
        #expect((1...6).map(BoardGenerator.startingPairs(forStage:)) == [3...5, 2...4, 2...3, 2...3, 2...3, 2...3])
        #expect((1...6).map(BoardGenerator.typicalMoves(forStage:)) == [8, 7, 6, 6, 5, 5])
        var session = GameSession(board: makeBoard([[0, 0, 0, 0, 0, 0, 0, 2, 8]]), stage: 4)
        _ = session.match(at: 7, 8)
        #expect(session.stage == 5)
        #expect(session.plusRemaining == 3)
        #expect(session.board.cells.count == 54)
        #expect(BoardGenerator.startingPairs(forStage: 5).contains(MatchRules.validPairs(on: session.board).count))
    }

    @Test func hintsAndPlusAreCountedPerBoard() {
        var session = GameSession(board: makeBoard([[0, 0, 0, 0, 0, 2, 8, 1, 9]]))
        _ = session.useHint()
        session.addNumbers()
        #expect(session.hintsOnBoard == 1 && session.usedPlusOnBoard)
        // Clear the original 2-8 and 1-9 and their copies.
        while let pair = MatchRules.validPairs(on: session.board).first, session.stage == 1 {
            let outcome = session.match(at: pair.first, pair.second)
            if outcome?.boardCleared == true {
                #expect(outcome?.hintsOnBoard == 1)
                #expect(outcome?.usedPlusOnBoard == true)
            }
        }
        #expect(session.stage == 2)
        #expect(session.hintsOnBoard == 0 && !session.usedPlusOnBoard)
        #expect(session.hintsUsed == 1)
    }

    @Test func gamesSavedBeforePerBoardHintsStillLoad() throws {
        var session = GameSession(seed: 7)
        _ = session.useHint()
        let data = try JSONEncoder().encode(session)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["hintsAtBoardStart"] = nil
        let old = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.hintsOnBoard == 1)
    }

    @Test func boardBonusScalesWithStage() {
        var session = GameSession(board: makeBoard([[0, 0, 0, 0, 0, 0, 0, 2, 8]]), stage: 3)
        let outcome = session.match(at: 7, 8)
        // From stage 3 every pair is worth one more.
        #expect(outcome?.points == 2 + 10 + 150 * 3)
        #expect(session.stage == 4)
    }

    @Test func dailyEndsAfterOneStage() {
        var session = GameSession(board: makeBoard([[0, 0, 0, 0, 0, 0, 0, 2, 8]]), mode: .daily(dayKey: "2026-10-25"))
        let outcome = session.match(at: 7, 8)
        #expect(outcome?.boardCleared == true)
        #expect(session.isCompleted)
        #expect(session.isOver)
        #expect(session.stage == 1)
    }

    @Test func dailyGoesOnToNextStageUntilTheGoal() {
        let board = makeBoard([[0, 0, 0, 0, 0, 0, 0, 2, 8]])
        var session = GameSession(board: board, mode: .daily(dayKey: "2026-10-27"), goal: 400)
        let cleared = session.match(at: 7, 8)
        #expect(cleared?.boardCleared == true && cleared?.reachedGoal == false)
        #expect(session.stage == 2 && !session.isCompleted && !session.isOver)
        #expect(session.board.cells.count == BoardGenerator.initialCount(forStage: 2))

        var near = GameSession(board: board, mode: .daily(dayKey: "2026-10-27"), score: 300, goal: 400)
        let outcome = near.match(at: 7, 8)
        #expect(outcome?.reachedGoal == true)
        // Reaching the goal ends the game, even on a cleared board: no next stage.
        #expect(near.isCompleted && near.isOver && near.stage == 1)
    }

    @Test func nothingIsPlayableAfterTheGoal() throws {
        var session = GameSession(board: makeBoard([[4, 4, 1, 2, 1, 2, 1, 2, 3, 7]]), mode: .daily(dayKey: "2026-10-27"), score: 399, goal: 400)
        _ = session.match(at: 0, 1)
        #expect(session.isCompleted && session.isOver)
        #expect(session.useHint() == nil)
        #expect(session.match(at: 8, 9) == nil)
        #expect(!session.addNumbers() && !session.canUndo)
        #expect(session.score == 400)
    }

    @Test func statsCountTheGameAndUndoTakesTheMoveBack() throws {
        var session = GameSession(board: makeBoard([[4, 4, 1, 2, 1, 2, 1, 2, 3], [7, 5, 5, 6, 6, 1, 1, 2, 3]]))
        _ = session.match(at: 0, 1)
        _ = session.match(at: 8, 9)
        session.addNumbers()
        #expect(session.stats == GameSession.Stats(pairs: 2, rowsCleared: 0, plusUsed: 1, longestStreak: 2))
        session.undo()
        #expect(session.stats.plusUsed == 0 && session.stats.pairs == 2)
        _ = session.match(at: 10, 11)
        session.undo()
        #expect(session.stats.pairs == 2)
    }

    @Test func timeCountsOnlyFromTheFirstMoveUntilTheEnd() {
        var session = GameSession(board: makeBoard([[4, 4, 1, 2, 1, 2, 1, 2, 3, 7]]), mode: .daily(dayKey: "2026-10-27"), score: 0, goal: 2)
        session.addTime(30)
        #expect(session.elapsedSeconds == 0)
        _ = session.match(at: 0, 1)
        session.addTime(12)
        #expect(session.elapsedSeconds == 12)
        _ = session.match(at: 8, 9)
        #expect(session.isOver)
        session.addTime(5)
        #expect(session.elapsedSeconds == 12)
    }

    @Test func dailiesSavedBeforeGoalsKeepTheOldRule() throws {
        let board = makeBoard([[0, 0, 0, 0, 0, 0, 0, 2, 8]])
        let session = GameSession(board: board, mode: .daily(dayKey: "2026-10-26"), goal: 500)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as! [String: Any]
        json["goal"] = nil
        var old = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.goal == nil)
        _ = old.match(at: 7, 8)
        #expect(old.isCompleted && old.isOver && old.stage == 1)
    }

    @Test func hintReturnsValidPairAndCostsPoints() throws {
        var session = GameSession(board: makeBoard([[1, 2, 3, 3, 1, 2, 1, 2, 1]]), score: 25)
        let result = session.useHint()
        let hint = try #require(result)
        #expect(MatchRules.pair(on: session.board, hint.pair.first, hint.pair.second) != nil)
        #expect(hint.cost == 10)
        #expect(session.score == 15)
        #expect(session.hintsUsed == 1)
    }

    @Test func hintCanTakeScoreBelowZero() throws {
        var session = GameSession(board: makeBoard([[1, 2, 3, 3, 1, 2, 1, 2, 1]]), score: 2)
        let result = session.useHint()
        let hint = try #require(result)
        #expect(hint.cost == 10)
        #expect(session.score == -8)
    }

    @Test func cheapHintsCostThree() throws {
        var session = GameSession(values: [1, 2, 3, 3, 1, 2, 1, 2, 1], seed: 0, scoring: .cheapHints)
        let result = session.useHint()
        let hint = try #require(result)
        #expect(hint.cost == 3)
        #expect(session.score == -3)
    }

    @Test func hintIsFreeWithoutPairs() {
        var session = GameSession(board: makeBoard([[1, 2, 1, 2, 1, 2, 1, 2, 1]]), score: 30)
        let hint = session.useHint()
        #expect(hint?.pair == nil)
        #expect(session.score == 30)
        #expect(session.hintsUsed == 0)
    }

    @Test func pairReportsGap() {
        var session = GameSession(board: makeBoard([[6, 0, 0, 0, 4, 1, 2, 1, 2]]))
        let outcome = session.match(at: 0, 4)
        #expect(outcome?.pair.gap == 3)
    }

    @Test func streakCountsMatchesAndResetsOnMissOrHint() {
        var session = GameSession(board: makeBoard([
            [1, 1, 2, 2, 3, 3, 4, 4, 5],
            [5, 6, 6, 7, 7, 8, 8, 9, 9],
        ]), score: 10)
        _ = session.match(at: 0, 1)
        _ = session.match(at: 2, 3)
        #expect(session.streak == 2)
        session.registerMiss()
        #expect(session.streak == 0)
        _ = session.match(at: 4, 5)
        #expect(session.streak == 1)
        _ = session.useHint()
        #expect(session.streak == 0)
        session.addNumbers()
        _ = session.match(at: 6, 7)
        #expect(session.streak == 1)
    }

    @Test func pairReportsRoute() {
        let board = makeBoard([
            [2, 1, 2, 1, 2, 1, 2, 1, 7],
            [3, 2, 1, 2, 1, 2, 1, 2, 1],
        ])
        #expect(MatchRules.pair(on: board, 8, 9)?.route == .readingOrder)
        let straight = makeBoard([[4, 4, 1, 2, 1, 2, 1, 2, 1]])
        #expect(MatchRules.pair(on: straight, 0, 1)?.route == .line)
    }

    @Test func undoTakesBackTheLastMatch() {
        var session = GameSession(board: makeBoard([
            [0, 0, 0, 0, 0, 0, 0, 3, 7],
            [4, 4, 2, 1, 2, 1, 2, 1, 2],
        ]))
        let before = session.board
        _ = session.match(at: 7, 8)
        #expect(session.canUndo)
        let undone = session.undo()
        #expect(undone)
        #expect(session.board == before)
        #expect(session.score == 0)
        #expect(session.streak == 0)
        // Only one step back.
        #expect(!session.canUndo)
        let undoneAgain = session.undo()
        #expect(!undoneAgain)
    }

    @Test func undoTakesBackPlus() {
        var session = GameSession(board: makeBoard([[1, 2, 1, 2, 1, 2, 1, 2, 1]]))
        session.addNumbers()
        let undone = session.undo()
        #expect(undone)
        #expect(session.board.cells.count == 9)
        #expect(session.plusRemaining == GameSession.maxPlusUses)
    }

    @Test func undoDoesNotRefundHintsOrRestoreBrokenStreaks() {
        var session = GameSession(board: makeBoard([[4, 4, 3, 3, 1, 2, 1, 2, 1]]), score: 10)
        _ = session.match(at: 0, 1)
        #expect(session.score == 11 && session.streak == 1)
        _ = session.useHint()
        #expect(session.score == 1)
        session.undo()
        #expect(session.score == 0)
        #expect(session.streak == 0)
    }

    @Test func noUndoAfterClearingTheBoard() {
        var session = GameSession(board: makeBoard([[0, 0, 0, 0, 0, 0, 0, 2, 8]]))
        _ = session.match(at: 7, 8)
        #expect(session.stage == 2)
        #expect(!session.canUndo)
    }

    @Test func noUndoOnceTheGameIsOver() {
        // After 1-1, nothing pairs: 2|3 meet across the gap, 3 _ 3 is blocked by the 4.
        var session = GameSession(board: makeBoard([[1, 2, 1, 2, 1, 1, 3, 4, 3]]), plusRemaining: 0)
        _ = session.match(at: 4, 5)
        #expect(session.isOver)
        #expect(!session.canUndo)
    }

    @Test func reportsDigitsWithNoneLeft() {
        var session = GameSession(board: makeBoard([[3, 7, 7, 1, 2, 1, 2, 1, 2]]))
        let outcome = session.match(at: 0, 1)
        #expect(outcome?.clearedDigits == [3])
    }

    @Test func plusMarksAddedCells() {
        var session = GameSession(board: makeBoard([[1, 2, 1, 2, 1, 2, 1, 2, 1]]))
        session.addNumbers()
        #expect(session.board.cells.prefix(9).allSatisfy { !$0.isAdded })
        #expect(session.board.cells.dropFirst(9).allSatisfy { $0.isAdded })
    }

    @Test func sessionRoundTripsThroughCodable() throws {
        var session = GameSession(seed: 42)
        session.addNumbers()
        let data = try JSONEncoder().encode(session)
        #expect(try JSONDecoder().decode(GameSession.self, from: data) == session)
    }
}
