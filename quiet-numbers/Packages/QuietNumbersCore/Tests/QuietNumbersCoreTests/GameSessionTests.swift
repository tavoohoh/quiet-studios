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

    @Test func emptiedRowCollapsesAndGivesBonus() {
        var session = GameSession(board: makeBoard([
            [0, 0, 0, 0, 0, 0, 0, 3, 7],
            [2, 1, 2, 1, 2, 1, 2, 1, 2],
        ]), plusRemaining: 2)
        let outcome = session.match(at: 7, 8)
        #expect(outcome?.clearedRows == [0])
        #expect(outcome?.points == 1 + 10)
        #expect(session.board.rowCount == 1)
        #expect(session.board.cells.map(\.value) == [2, 1, 2, 1, 2, 1, 2, 1, 2])
        #expect(session.plusRemaining == 3)
    }

    @Test func rowBonusCapsAtMaxPlus() {
        var session = GameSession(board: makeBoard([
            [0, 0, 0, 0, 0, 0, 0, 3, 7],
            [2, 1, 2, 1, 2, 1, 2, 1, 2],
        ]))
        let outcome = session.match(at: 7, 8)
        #expect(outcome != nil)
        #expect(session.plusRemaining == GameSession.maxPlusUses)
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
        #expect(session.plusRemaining == 2)
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
        #expect(session.hintsRemaining == GameSession.initialHints + 1)
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

    @Test func hintReturnsValidPairAndSpendsOne() throws {
        var session = GameSession(board: makeBoard([[1, 2, 3, 3, 1, 2, 1, 2, 1]]))
        let hint = session.useHint()
        let pair = try #require(hint)
        #expect(MatchRules.pair(on: session.board, pair.first, pair.second) != nil)
        #expect(session.hintsRemaining == GameSession.initialHints - 1)
    }

    @Test func hintIsNotSpentWithoutPairs() {
        var session = GameSession(board: makeBoard([[1, 2, 1, 2, 1, 2, 1, 2, 1]]))
        let hint = session.useHint()
        #expect(hint == nil)
        #expect(session.hintsRemaining == GameSession.initialHints)
    }

    @Test func sessionRoundTripsThroughCodable() throws {
        var session = GameSession(seed: 42)
        session.addNumbers()
        let data = try JSONEncoder().encode(session)
        #expect(try JSONDecoder().decode(GameSession.self, from: data) == session)
    }
}
