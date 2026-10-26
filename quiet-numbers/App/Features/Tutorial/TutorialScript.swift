import Foundation
import QuietNumbersCore

/// The tutorial: a hand-made board where each move sets up the next.
/// Cell ids are the board's starting indices (rows of 9). `TutorialScriptTests` plays it
/// through a real `GameSession` to check every step is legal and leaves no pairs for +.
enum TutorialScript {
    enum Move: Equatable {
        /// Match these two cells.
        case pair(Int, Int)
        /// Tap +.
        case addNumbers
    }

    struct Step: Identifiable {
        let id: Int
        let move: Move
        let title: LocalizedStringResource
        let text: LocalizedStringResource
    }

    /// Row 0 has no pairs once the 8 is gone, and neither does what's left of row 2,
    /// so the last step really is "out of pairs".
    static let values = [
        1, 2, 3, 8, 4, 1, 2, 3, 5,
        7, 5, 5, 4, 2, 3, 6, 6, 9,
        1, 4, 5, 6,
    ]

    static let steps: [Step] = [
        Step(id: 1, move: .pair(10, 11), title: "Equal numbers",
             text: "Two equal numbers that touch are a pair. Match the two 5s."),
        Step(id: 2, move: .pair(12, 21), title: "Add up to 10",
             text: "Two numbers that add up to 10 are a pair too, and up and down counts. Match the 4 and the 6."),
        Step(id: 3, move: .pair(13, 3), title: "Diagonals",
             text: "Numbers touching on a diagonal count too. Match the 2 and the 8."),
        Step(id: 4, move: .pair(9, 14), title: "Long shot",
             text: "With only cleared cells between them, numbers still connect, and it's worth more: 4 points. Match the 7 and the 3."),
        Step(id: 5, move: .pair(17, 18), title: "Next row",
             text: "The board reads like a page: the end of a row connects to the start of the next. Match the 9 and the 1."),
        Step(id: 6, move: .pair(15, 16), title: "Clear a row",
             text: "Empty a whole row and it goes away, for 10 points. Match the last two 6s."),
        Step(id: 7, move: .addNumbers, title: "Out of pairs?",
             text: "No pairs left. Tap + to copy the numbers left to the end of the board. You get 5 per board."),
    ]

    static func session() -> GameSession {
        GameSession(values: values, seed: 0)
    }

    /// Whether `step` has been played on `session`.
    static func isDone(_ step: Step, on session: GameSession) -> Bool {
        switch step.move {
        case .pair(let a, let b):
            [a, b].allSatisfy { id in
                session.board.index(ofCell: id).map { session.board.cells[$0].isCleared } ?? true
            }
        case .addNumbers:
            session.plusRemaining < GameSession.maxPlusUses
        }
    }
}
