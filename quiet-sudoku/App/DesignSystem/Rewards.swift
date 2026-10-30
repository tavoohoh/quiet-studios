import QuietCore
import QuietSudokuCore
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

/// The board: the family's palettes.
enum BoardChoice: String, Reward {
    case tealCoral, tealCoralLight, tealCoralDark, sageSand, indigoPeach, sageCoral, highContrast

    var title: LocalizedStringResource {
        switch self {
        case .tealCoral: "Teal & Coral"
        case .tealCoralLight: "Teal & Coral Light"
        case .tealCoralDark: "Teal & Coral Dark"
        case .sageSand: "Sage & Sand"
        case .indigoPeach: "Indigo & Peach"
        case .sageCoral: "Sage & Coral"
        case .highContrast: "High contrast"
        }
    }

    var unlockedBy: Achievement? {
        switch self {
        case .tealCoral, .tealCoralLight, .tealCoralDark, .highContrast: nil
        case .sageSand: .noHints
        case .indigoPeach: .consistency
        case .sageCoral: .nightOwl
        }
    }

    var note: LocalizedStringResource? {
        // Separate returns: string extraction skips literals after the first case of a switch here.
        if self == .tealCoral { return "Follows your device's light or dark mode." }
        if self == .highContrast { return "Always available for low vision." }
        return nil
    }

    /// Teal & Coral Light and Dark are Teal & Coral pinned to one mode.
    var palette: Palette {
        switch self {
        case .tealCoral, .tealCoralLight, .tealCoralDark: .tealCoral
        default: Palette(rawValue: rawValue)!
        }
    }

    /// Teal & Coral follows the system, or stays light or dark whatever the device uses;
    /// the others have a single mode of their own.
    var theme: Theme {
        switch self {
        case .tealCoralLight: Theme(palette, colorScheme: .light)
        case .tealCoralDark: Theme(palette, colorScheme: .dark)
        default: Theme(palette)
        }
    }
}

/// The digits' typeface. System fonts only: nothing to license.
enum DigitStyle: String, Reward {
    case rounded, classic, mono, pen

    var title: LocalizedStringResource {
        switch self {
        case .rounded: "Rounded"
        case .classic: "Classic"
        case .mono: "Typewriter"
        case .pen: "Pen"
        }
    }

    var unlockedBy: Achievement? {
        switch self {
        case .rounded: nil
        case .classic: .noMistakes
        case .mono: .noNotes
        case .pen: .expert
        }
    }

    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .rounded: .system(size: size, weight: weight, design: .rounded)
        case .classic: .system(size: size, weight: weight, design: .serif)
        case .mono: .system(size: size, weight: weight == .regular ? .regular : .medium, design: .monospaced)
        case .pen: .custom("Noteworthy-Bold", fixedSize: size * 1.05)
        }
    }
}

/// Pencil marks in the muted ink, or in the accent.
enum NotesStyle: String, Reward {
    case plain, colored

    var title: LocalizedStringResource {
        switch self {
        case .plain: "Plain"
        case .colored: "In color"
        }
    }

    var unlockedBy: Achievement? { self == .colored ? .tenWins : nil }
}

/// What lights up around the selected cell.
enum HighlightStyle: String, Reward {
    /// Its row, column and box, and the same digit everywhere.
    case full
    /// Only the same digit.
    case soft

    var title: LocalizedStringResource {
        switch self {
        case .full: "Row, column and box"
        case .soft: "Same digit only"
        }
    }

    var unlockedBy: Achievement? { self == .soft ? .quick : nil }
}

/// Every win ends in fireworks; Wave first lights the board up from the last digit.
enum VictoryEffect: String, Reward {
    case fireworks, wave

    var title: LocalizedStringResource {
        switch self {
        case .fireworks: "Fireworks"
        case .wave: "Wave and fireworks"
        }
    }

    var unlockedBy: Achievement? { self == .wave ? .habit : nil }
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
    var digits: DigitStyle = .rounded
    var notes: NotesStyle = .plain
    var highlight: HighlightStyle = .full
    var victory: VictoryEffect = .fireworks
    /// Bigger digits and notes (always available, for low vision).
    var largeDigits = false
    /// Wrong digits turn red as soon as they're written (default), or only once the board is full.
    var showsMistakes = true
}

extension EnvironmentValues {
    @Entry var appearance = Appearance()
}

/// Storage keys for preferences (UserDefaults).
enum PreferenceKey {
    static let board = "board"
    static let digits = "digits"
    static let notes = "notes"
    static let highlight = "highlight"
    static let victory = "victory"
    static let appIcon = "appIcon"
    static let soundEnabled = "soundEnabled"
    static let hapticsEnabled = "hapticsEnabled"
    static let showsMistakes = "showsMistakes"
    static let largeDigits = "largeDigits"
    /// The level of the last classic game, offered first next time.
    static let classicDifficulty = "classicDifficulty"
    /// The tutorial was played or skipped. Cleared by a reset, like a fresh install.
    static let tutorialSeen = "tutorialSeen"
    /// Set by a reset until the iCloud copy and achievements are cleared too.
    static let pendingCloudReset = "pendingCloudReset"

    /// Cosmetic choices, cleared by a reset.
    static let rewards = [board, digits, notes, highlight, victory, appIcon]
}
