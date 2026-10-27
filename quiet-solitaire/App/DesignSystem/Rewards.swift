import QuietCore
import QuietSolitaireCore
import QuietUI
import SwiftUI

/// A cosmetic option in the Collection. Some are free; the rest unlock with an achievement.
protocol Reward: CaseIterable, Hashable, RawRepresentable<String> {
    var title: LocalizedStringResource { get }
    var unlockedBy: Achievement? { get }
    /// Shown instead of an unlock condition (always-available accessibility options).
    var note: LocalizedStringResource? { get }
}

extension Reward {
    var note: LocalizedStringResource? { nil }

    func isUnlocked(in progress: PlayerProgress) -> Bool {
        unlockedBy.map(progress.unlocked.contains) ?? true
    }
}

/// The table: the family's palettes.
enum BoardChoice: String, Reward {
    case tealCoral, sageSand, indigoPeach, sageCoral, highContrast

    var title: LocalizedStringResource {
        switch self {
        case .tealCoral: "Teal & Coral"
        case .sageSand: "Sage & Sand"
        case .indigoPeach: "Indigo & Peach"
        case .sageCoral: "Sage & Coral"
        case .highContrast: "High contrast"
        }
    }

    var unlockedBy: Achievement? {
        switch self {
        case .tealCoral, .highContrast: nil
        case .sageSand: .noHints
        case .indigoPeach: .consistency
        case .sageCoral: .tenWins
        }
    }

    var note: LocalizedStringResource? { self == .highContrast ? "Always available for low vision." : nil }

    var palette: Palette { Palette(rawValue: rawValue)! }
}

/// Card faces.
enum DeckStyle: String, Reward {
    case quiet, illustrated, classic, pixel, fourColor, largeIndex

    var title: LocalizedStringResource {
        switch self {
        case .quiet: "Quiet"
        case .illustrated: "Illustrated"
        case .classic: "Classic"
        case .pixel: "Pixel"
        case .fourColor: "Four colors"
        case .largeIndex: "Large index"
        }
    }

    var unlockedBy: Achievement? {
        switch self {
        case .quiet, .fourColor, .largeIndex: nil
        case .illustrated: .habit
        case .classic: .onePass
        case .pixel: .economy
        }
    }

    var note: LocalizedStringResource? {
        switch self {
        case .fourColor: "Always available to tell suits apart."
        case .largeIndex: "Always available for low vision."
        default: nil
        }
    }
}

enum CardBack: String, Reward {
    case theme, coral, linen, night, gold

    var title: LocalizedStringResource {
        switch self {
        case .theme: "Theme"
        case .coral: "Coral"
        case .linen: "Linen"
        case .night: "Night"
        case .gold: "Gold"
        }
    }

    var unlockedBy: Achievement? {
        switch self {
        case .theme: nil
        case .coral: .noUndo
        case .linen: .ladder
        case .night: .nightOwl
        case .gold: .centennial
        }
    }
}

enum VictoryEffect: String, Reward {
    case gentle, cascade

    var title: LocalizedStringResource {
        switch self {
        case .gentle: "Gentle"
        case .cascade: "Cascade"
        }
    }

    var unlockedBy: Achievement? { self == .cascade ? .fiftyWins : nil }
}

enum AppIconChoice: String, Reward {
    case standard, gold

    var title: LocalizedStringResource {
        switch self {
        case .standard: "Standard"
        case .gold: "Gold"
        }
    }

    var unlockedBy: Achievement? { self == .gold ? .centennial : nil }

    /// Name for `setAlternateIconName`; `nil` is the primary icon.
    var iconName: String? { self == .gold ? "AppIcon-Gold" : nil }
}

/// The player's chosen cosmetics and options, read by the board.
struct Appearance {
    var deck: DeckStyle = .quiet
    var back: CardBack = .theme
    var victory: VictoryEffect = .gentle
    var leftHanded = false
}

extension EnvironmentValues {
    @Entry var appearance = Appearance()
}

/// Storage keys for preferences (UserDefaults).
enum PreferenceKey {
    static let board = "board"
    static let deck = "deck"
    static let back = "back"
    static let victory = "victory"
    static let appIcon = "appIcon"
    static let soundEnabled = "soundEnabled"
    static let hapticsEnabled = "hapticsEnabled"
    static let tapToMove = "tapToMove"
    static let winnableOnly = "winnableOnly"
    static let leftHanded = "leftHanded"
    /// Set by a reset until the iCloud copy and achievements are cleared too.
    static let pendingCloudReset = "pendingCloudReset"

    /// Cosmetic choices, cleared by a reset.
    static let rewards = [board, deck, back, victory, appIcon]
}
