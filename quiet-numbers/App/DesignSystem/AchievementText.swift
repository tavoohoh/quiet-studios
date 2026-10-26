import QuietNumbersCore
import SwiftUI

/// Localized names and conditions. Game Center's own copies live in App Store Connect.
extension Achievement {
    var title: LocalizedStringResource {
        switch self {
        case .firstStep: "First Step"
        case .cleanSlate: "Clean Slate"
        case .noHelp: "No Help"
        case .consistency: "Consistency"
        case .habit: "Habit"
        case .sweeper: "Sweeper"
        case .stageFive: "Stage 5"
        case .centennial: "Centennial"
        case .nightOwl: "Night Owl"
        case .monotone: "Monotone"
        }
    }

    var condition: LocalizedStringResource {
        switch self {
        case .firstStep: "Finish your first game."
        case .cleanSlate: "Clear a whole board."
        case .noHelp: "Clear a board without + or hints."
        case .consistency: "Complete 7 daily challenges in a row."
        case .habit: "Complete 30 daily challenges in a row."
        case .sweeper: "Clear 100 rows."
        case .stageFive: "Reach stage 5 in one game."
        case .centennial: "Complete 100 daily challenges."
        case .nightOwl: "Complete a daily challenge between midnight and 4 a.m."
        case .monotone: "Make 10 pairs of equal numbers in a row."
        }
    }

    var systemImage: String {
        switch self {
        case .firstStep: "figure.walk"
        case .cleanSlate: "square.dashed"
        case .noHelp: "hand.raised.slash"
        case .consistency: "calendar"
        case .habit: "calendar.badge.checkmark"
        case .sweeper: "wind"
        case .stageFive: "5.circle"
        case .centennial: "rosette"
        case .nightOwl: "moon.stars"
        case .monotone: "equal.circle"
        }
    }
}
