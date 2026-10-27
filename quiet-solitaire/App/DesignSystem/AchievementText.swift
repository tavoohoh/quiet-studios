import QuietSolitaireCore
import SwiftUI

/// Localized names and conditions. Game Center's own copies live in App Store Connect.
extension Achievement {
    var title: LocalizedStringResource {
        switch self {
        case .firstWin: "First Hand"
        case .noUndo: "No Going Back"
        case .noHints: "Steady Hand"
        case .onePass: "One Pass"
        case .tenWins: "Ten Wins"
        case .consistency: "Consistency"
        case .habit: "Habit"
        case .ladder: "Ladder"
        case .centennial: "Centennial"
        case .nightOwl: "Night Owl"
        case .fiftyWins: "Fifty"
        case .economy: "Economy"
        case .inTheRed: "In the Red"
        }
    }

    var condition: LocalizedStringResource {
        switch self {
        case .firstWin: "Win your first game."
        case .noUndo: "Win without undo."
        case .noHints: "Win without hints."
        case .onePass: "Win without recycling the stock."
        case .tenWins: "Win 10 games."
        case .consistency: "Complete 7 daily challenges in a row."
        case .habit: "Complete 30 daily challenges in a row."
        case .ladder: "Build a column from king to ace."
        case .centennial: "Win 100 games."
        case .nightOwl: "Win a daily challenge between midnight and 4 a.m."
        case .fiftyWins: "Win 50 games."
        case .economy: "Win in fewer than 100 moves."
        case .inTheRed: "Take your score below zero."
        }
    }

    /// Game Center identifier (App Store Connect).
    var gameCenterID: String {
        "qs_" + rawValue.replacing(/([A-Z])/) { "_" + $0.output.1.lowercased() }
    }

    var systemImage: String {
        switch self {
        case .firstWin: "hand.raised"
        case .noUndo: "arrow.uturn.backward.circle"
        case .noHints: "lightbulb.slash"
        case .onePass: "arrow.forward.circle"
        case .tenWins: "10.circle"
        case .consistency: "calendar"
        case .habit: "calendar.badge.checkmark"
        case .ladder: "stairs"
        case .centennial: "rosette"
        case .nightOwl: "moon.stars"
        case .fiftyWins: "50.circle"
        case .economy: "bolt"
        case .inTheRed: "minus.circle"
        }
    }
}
