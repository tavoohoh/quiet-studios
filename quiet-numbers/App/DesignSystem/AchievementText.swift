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
        case .inTheRed: "In the Red"
        }
    }

    var condition: LocalizedStringResource {
        switch self {
        case .firstStep: "Clear your first board or finish your first game."
        case .cleanSlate: "Clear a board without using +."
        case .noHelp: "Clear a board without using hints."
        case .consistency: "Complete 7 daily challenges in a row."
        case .habit: "Complete 30 daily challenges in a row."
        case .sweeper: "Clear 100 rows."
        case .stageFive: "Reach stage 5 in one game."
        case .centennial: "Complete 100 daily challenges."
        case .nightOwl: "Complete a daily challenge between midnight and 4 a.m."
        case .monotone: "Make 10 pairs of equal numbers in a row."
        case .inTheRed: "Take your score below zero."
        }
    }

    /// The badge from the design system (same art as Game Center's), from render-artwork.py.
    var badge: Image { Image("badge-\(gameCenterID)") }
}
