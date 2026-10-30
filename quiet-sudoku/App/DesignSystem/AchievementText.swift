import QuietSudokuCore
import SwiftUI

/// Localized names and conditions. Game Center's own copies live in App Store Connect.
extension Achievement {
    var title: LocalizedStringResource {
        switch self {
        case .firstWin: "First Sudoku"
        case .noMistakes: "Clean Sheet"
        case .noHints: "On Your Own"
        case .noNotes: "From Memory"
        case .tenWins: "Ten Sudokus"
        case .consistency: "Consistency"
        case .habit: "Habit"
        case .expert: "Expert"
        case .quick: "Quick"
        case .nightOwl: "Night Owl"
        case .centennial: "Centennial"
        case .inTheRed: "In the Red"
        }
    }

    var condition: LocalizedStringResource {
        switch self {
        case .firstWin: "Solve your first sudoku."
        case .noMistakes: "Solve a sudoku without mistakes."
        case .noHints: "Solve a sudoku without hints."
        case .noNotes: "Solve a medium or harder sudoku without notes."
        case .tenWins: "Solve 10 sudokus."
        case .consistency: "Complete 7 daily challenges in a row."
        case .habit: "Complete 30 daily challenges in a row."
        case .expert: "Solve an expert sudoku."
        case .quick: "Solve an easy sudoku in under 4 minutes."
        case .nightOwl: "Solve a daily challenge between midnight and 4 a.m."
        case .centennial: "Solve 100 sudokus."
        case .inTheRed: "Take your score below zero."
        }
    }

    /// Game Center identifier (App Store Connect).
    var gameCenterID: String {
        "qsu_" + rawValue.replacing(/([A-Z])/) { "_" + $0.output.1.lowercased() }
    }

    var systemImage: String {
        switch self {
        case .firstWin: "square.grid.3x3"
        case .noMistakes: "checkmark.seal"
        case .noHints: "lightbulb.slash"
        case .noNotes: "pencil.slash"
        case .tenWins: "10.circle"
        case .consistency: "calendar"
        case .habit: "calendar.badge.checkmark"
        case .expert: "star.circle"
        case .quick: "bolt"
        case .nightOwl: "moon.stars"
        case .centennial: "rosette"
        case .inTheRed: "minus.circle"
        }
    }
}

/// What a hint says: the technique's name and, for the digit it places, why.
extension Technique {
    var title: LocalizedStringResource {
        switch self {
        case .fullHouse: "Last empty cell"
        case .hiddenSingle: "Only place"
        case .nakedSingle: "Only digit"
        case .pointing: "Pointing"
        case .claiming: "Box and line"
        case .nakedPair: "Naked pair"
        case .hiddenPair: "Hidden pair"
        case .nakedTriple: "Naked triple"
        case .hiddenTriple: "Hidden triple"
        case .xWing: "X-Wing"
        case .xyWing: "XY-Wing"
        case .skyscraper: "Skyscraper"
        case .twoStringKite: "2-String Kite"
        case .swordfish: "Swordfish"
        case .xyzWing: "XYZ-Wing"
        case .wWing: "W-Wing"
        }
    }

    /// One or two sentences for Settings › Techniques.
    var explanation: LocalizedStringResource {
        switch self {
        case .fullHouse: "A row, column or box with one empty cell: it takes the missing digit."
        case .hiddenSingle: "In a row, column or box, a digit fits in only one cell because its other copies rule out the rest."
        case .nakedSingle: "A cell's row, column and box already hold eight different digits: the ninth goes there."
        case .pointing: "In a box, a digit's only cells lie on one line. It must be there, so it's not elsewhere on that line."
        case .claiming: "On a row or column, a digit's only cells lie in one box. It's not in the rest of that box."
        case .nakedPair: "Two cells of a house with the same two candidates: those digits go there, so not in the house's other cells."
        case .hiddenPair: "Two digits that fit in only the same two cells of a house: those cells hold nothing else."
        case .nakedTriple: "Three cells of a house holding only three digits between them: not elsewhere in the house."
        case .hiddenTriple: "Three digits that fit in only the same three cells of a house: those cells hold nothing else."
        case .xWing: "A digit fits twice on two rows, in the same two columns. It takes those columns there, so not elsewhere in them (or rows and columns swapped)."
        case .xyWing: "A cell {x, y} sees cells {x, z} and {y, z}. One of those two is z, so a cell seeing both can't be z."
        case .skyscraper: "Two rows with two spots each for a digit, one pair lined up. One of the other two ends holds it: a cell seeing both can't."
        case .twoStringKite: "A row and a column with two spots each for a digit, linked through a box. One of the far ends holds it: a cell seeing both can't."
        case .swordfish: "Like an X-Wing with three rows and three columns."
        case .xyzWing: "A cell {x, y, z} sees cells {x, z} and {y, z}. One of the three is z, so a cell seeing all three can't be z."
        case .wWing: "Two cells {x, y} linked by a house where x has two spots, one seen by each. One of the two cells is y: a cell seeing both can't be."
        }
    }
}

extension UnitKind {
    /// "row 3", "column 7", "box 5", counting from 1.
    func name(_ index: Int) -> String {
        switch self {
        case .row: String(localized: "row \(index + 1)")
        case .column: String(localized: "column \(index + 1)")
        case .box: String(localized: "box \(index + 1)")
        }
    }
}

/// The house a unit index names, in words.
func unitName(_ unit: Int) -> String {
    UnitKind(unit: unit).name(unit % 9)
}
