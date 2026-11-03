import Foundation
import QuietSudokuCore
import SwiftData
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
    func writeANote(_ digit: Int = 1) {
        let cell = (0..<81).first { session.values[$0] == 0 }!
        select(cell)
        isNoting = true
        input(digit)
        isNoting = false
    }

    /// A wrong digit in the first empty cell, erased right away (it still costs).
    func writeAMistake() {
        let cell = (0..<81).first { session.values[$0] == 0 }!
        select(cell)
        isNoting = false
        input(session.puzzle.solution[cell] % 9 + 1)
        erase()
    }
}

@MainActor
extension PersistenceService {
    /// A game in a slot from before 2026-11-02 ("daily", "practice-<day>").
    func saveLegacyGame(_ session: GameSession, slot: String, updatedAt: Date) {
        container.mainContext.insert(StoredGame(slot: slot, data: try! JSONEncoder().encode(session), updatedAt: updatedAt))
        try? container.mainContext.save()
    }
}
