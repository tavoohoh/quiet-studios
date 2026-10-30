import Testing
@testable import QuietSudokuCore

/// The tutorial teaches from scratch: every lesson has one answer, and it follows from what
/// that lesson and the earlier ones taught.
@Suite struct TutorialTests {
    @Test func lessonsInOrder() {
        #expect(Tutorial.lessons.map(\.kind) == Tutorial.Kind.allCases)
    }

    @Test(arguments: Tutorial.lessons)
    func boardIsAValidPuzzle(_ lesson: Tutorial.Lesson) {
        let givens = lesson.puzzle.givens
        #expect(givens.isConsistent)
        #expect(DancingLinks.solutions(of: givens) == [lesson.puzzle.solution])
        #expect(Backtracker.countSolutions(givens) == 1)
        #expect(givens[lesson.target] == 0)
        if lesson.digit != 0 { #expect(lesson.puzzle.solution[lesson.target] == lesson.digit) }
    }

    @Test(arguments: Tutorial.lessons.filter { [.row, .column, .box].contains($0.kind) })
    func lastCellOfAHouse(_ lesson: Tutorial.Lesson) {
        let values = lesson.puzzle.givens.cells
        let house = lesson.units[0]
        let kind: UnitKind = switch lesson.kind { case .row: .row; case .column: .column; default: .box }
        #expect(UnitKind(unit: house) == kind)
        #expect(Grid.units[house].filter { values[$0] == 0 } == [lesson.target])
        // The other two houses of the cell don't give it away.
        for unit in Grid.unitsOfCell[lesson.target] where unit != house {
            #expect(Grid.units[unit].count { values[$0] == 0 } >= 2)
        }
        // The digit is the one missing from the house.
        let present = Set(Grid.units[house].map { values[$0] })
        #expect(!present.contains(lesson.digit))
    }

    @Test func crossHatchNeedsOnlyTheBox() {
        let lesson = Tutorial.lessons.first { $0.kind == .crossHatch }!
        let solver = LogicSolver(lesson.puzzle.givens)
        let box = lesson.units[0]
        #expect(UnitKind(unit: box) == .box)
        let bit = Digits.bit(lesson.digit)
        #expect(Grid.units[box].filter { solver.candidates[$0] & bit != 0 } == [lesson.target])
        // More than one digit fits the cell itself: it takes looking at the box.
        #expect(solver.candidates[lesson.target].nonzeroBitCount >= 2)
        // Every other empty cell of the box is ruled out by a copy of the digit it sees.
        for cell in Grid.units[box] where cell != lesson.target && solver.values[cell] == 0 {
            #expect(lesson.clues.contains { Grid.sees($0, cell) && solver.values[$0] == lesson.digit })
        }
        #expect(LogicSolver.solve(lesson.puzzle.givens, upTo: .easy).solved)
    }

    @Test func onlyOneDigitFits() {
        let lesson = Tutorial.lessons.first { $0.kind == .onlyOne }!
        let solver = LogicSolver(lesson.puzzle.givens)
        #expect(Digits.list(solver.candidates[lesson.target]) == [lesson.digit])
        // Not the last cell of a house, nor the only spot of the digit in one.
        for unit in Grid.unitsOfCell[lesson.target] {
            #expect(Grid.units[unit].count { solver.values[$0] == 0 } >= 2)
            #expect(Grid.units[unit].count { solver.candidates[$0] & Digits.bit(lesson.digit) != 0 } >= 2)
        }
        // The eight other digits are all in the cell's row, column or box.
        let seen = Set(lesson.clues.map { solver.values[$0] })
        #expect(seen == Set(1...9).subtracting([lesson.digit]))
    }

    @Test func notesAreTheCandidates() {
        let lesson = Tutorial.lessons.first { $0.kind == .notes }!
        let solver = LogicSolver(lesson.puzzle.givens)
        #expect(lesson.notes.count == 3)
        #expect(Digits.list(solver.candidates[lesson.target]) == lesson.notes)
        #expect(lesson.notes.contains(lesson.puzzle.solution[lesson.target]))
    }

    @Test func hintPlacesTheTarget() {
        let lesson = Tutorial.lessons.first { $0.kind == .hint }!
        var game = GameSession(puzzle: lesson.puzzle)
        let hint = game.hint()!
        game.apply(hint)
        #expect(game.values[lesson.target] == lesson.digit)
        #expect(game.hintsUsed == 1)
        #expect(game.score == -10)
    }

    @Test func basePuzzleIsFixed() {
        // Changing the generator changes the tutorial: update this on purpose.
        #expect(Tutorial.base.givens.string == TutorialTests.baseGivens)
    }

    static let baseGivens = ".4.279.8.8...1..2.25....67..6.395...9.4...2.3...427.1..19....38.3..8...2.2.753.9."
}
