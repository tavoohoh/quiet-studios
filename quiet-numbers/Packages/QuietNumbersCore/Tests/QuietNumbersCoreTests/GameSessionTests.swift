import Foundation
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
        #expect(session.board.cells.count == BoardGenerator.initialCount)
    }

    @Test func boardBonusScalesWithStage() {
        var session = GameSession(board: makeBoard([[0, 0, 0, 0, 0, 0, 0, 2, 8]]), stage: 3)
        let outcome = session.match(at: 7, 8)
        #expect(outcome?.points == 1 + 10 + 150 * 3)
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

    @Test func hintReturnsValidPairAndCostsPoints() throws {
        var session = GameSession(board: makeBoard([[1, 2, 3, 3, 1, 2, 1, 2, 1]]), score: 25)
        let result = session.useHint()
        let hint = try #require(result)
        #expect(MatchRules.pair(on: session.board, hint.pair.first, hint.pair.second) != nil)
        #expect(hint.cost == 3)
        #expect(session.score == 22)
        #expect(session.hintsUsedThisStage == 1)
    }

    @Test func hintNeverTakesScoreBelowZero() throws {
        var session = GameSession(board: makeBoard([[1, 2, 3, 3, 1, 2, 1, 2, 1]]), score: 2)
        let result = session.useHint()
        let hint = try #require(result)
        #expect(hint.cost == 2)
        #expect(session.score == 0)
    }

    @Test func hintIsFreeWithoutPairs() {
        var session = GameSession(board: makeBoard([[1, 2, 1, 2, 1, 2, 1, 2, 1]]), score: 30)
        let hint = session.useHint()
        #expect(hint?.pair == nil)
        #expect(session.score == 30)
        #expect(session.hintsUsedThisStage == 0)
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
        #expect(session.score == 8)
        session.undo()
        #expect(session.score == 7)
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
