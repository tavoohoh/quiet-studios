import QuietSudokuCore
@testable import Quiet_Sudoku

/// Boards for app tests.
enum TestBoards {
    static let puzzle = Generator.puzzle(key: "app-tests", difficulty: .easy)

    /// Every cell right but the last empty one.
    @MainActor
    static func oneFromWin(_ mode: GameSession.Mode, seconds: Int = 0) -> GameModel {
        var values = puzzle.solution.cells
        values[lastEmpty] = 0
        return GameModel(session: GameSession(mode: mode, puzzle: puzzle, values: values, elapsedSeconds: seconds))
    }

    static var lastEmpty: Int { (0..<81).last { puzzle.givens[$0] == 0 }! }
}

@MainActor
extension GameModel {
    /// Writes the missing digit of a `oneFromWin` board.
    func playLastCell() {
        let cell = (0..<81).first { session.values[$0] == 0 }!
        select(cell)
        isNoting = false
        input(session.puzzle.solution[cell])
    }

    /// Any action that counts as playing: a note in the first empty cell.
    func writeANote() {
        let cell = (0..<81).first { session.values[$0] == 0 }!
        select(cell)
        isNoting = true
        input(1)
        isNoting = false
    }
}
