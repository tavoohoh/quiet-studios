import QuietSudokuCore
import Testing
@testable import Quiet_Sudoku

/// "Show mistakes right away" off: nothing red during play, the same cost, and the wrong
/// digits revealed once the board is full.
@MainActor
@Suite struct GameModelTests {
    @Test func hiddenMistakesCostTheSameAndShowWhenFull() {
        let model = TestBoards.oneFromWin(.classic)
        model.showsMistakes = false
        let cell = TestBoards.lastEmpty
        let right = model.session.puzzle.solution[cell]
        model.select(cell)
        model.input(right % 9 + 1)
        #expect(model.session.mistakes == 1)
        #expect(model.session.score == -20)
        // The board is full but wrong: the digit shows red now, and the game goes on.
        #expect(model.showsWrong(cell))
        #expect(!model.session.isWon)
        #expect(model.note != nil)
        model.input(right)
        #expect(model.session.isWon)
        #expect(!model.showsWrong(cell))
    }

    @Test func hiddenMistakeStaysHiddenBeforeTheBoardIsFull() {
        let model = GameModel(session: GameSession(puzzle: TestBoards.puzzle))
        model.showsMistakes = false
        let cell = (0..<81).first { TestBoards.puzzle.givens[$0] == 0 }!
        model.select(cell)
        model.input(TestBoards.puzzle.solution[cell] % 9 + 1)
        #expect(!model.showsWrong(cell))
        #expect(model.shownScore == 0)
        #expect(model.session.score == -20)
    }

    @Test func shownMistakeIsRedRightAway() {
        let model = GameModel(session: GameSession(puzzle: TestBoards.puzzle))
        let cell = (0..<81).first { TestBoards.puzzle.givens[$0] == 0 }!
        model.select(cell)
        model.input(TestBoards.puzzle.solution[cell] % 9 + 1)
        #expect(model.showsWrong(cell))
        #expect(model.shownScore == -20)
    }

    @Test func hintExplainsAndPlaces() {
        let model = GameModel(session: GameSession(puzzle: TestBoards.puzzle))
        model.requestHint()
        guard case .step(let step, _)? = model.hint, let placement = step.placement else {
            Issue.record("no hint")
            return
        }
        #expect(model.session.values[placement.cell] == placement.digit)
        #expect(!model.hint!.body.isEmpty)
        #expect(model.selected == placement.cell)
    }

    @Test func tutorialOnlyAcceptsTheAnswer() {
        let lesson = Tutorial.lessons[0]
        let model = GameModel(session: GameSession(puzzle: lesson.puzzle), isTutorial: true)
        model.setGuide(.init(cell: lesson.target, digits: [lesson.digit], asNotes: false))
        model.input(lesson.digit % 9 + 1)
        #expect(model.session.mistakes == 0)
        model.input(lesson.digit)
        #expect(model.session.values[lesson.target] == lesson.digit)
    }
}
