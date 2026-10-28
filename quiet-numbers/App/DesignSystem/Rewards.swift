import QuietCore
import QuietNumbersCore
import QuietUI
import SwiftUI

/// A cosmetic option in the Collection. Some are free; the rest unlock with an achievement.
protocol Reward: CaseIterable, Hashable, RawRepresentable<String> {
    var title: LocalizedStringResource { get }
    var unlockedBy: Achievement? { get }
}

extension Reward {
    func isUnlocked(in progress: PlayerProgress) -> Bool {
        unlockedBy.map(progress.unlocked.contains) ?? true
    }
}

enum ThemeChoice: String, Reward {
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

    /// The default in a fixed mode and High contrast (accessibility) are never locked.
    var unlockedBy: Achievement? {
        switch self {
        case .tealCoral, .tealCoralLight, .tealCoralDark, .highContrast: nil
        case .sageSand: .noHelp
        case .indigoPeach: .consistency
        case .sageCoral: .nightOwl
        }
    }

    /// Shown instead of an unlock condition.
    var note: LocalizedStringResource? {
        // Separate returns: string extraction skips literals after the first case of a switch here.
        if self == .tealCoral { return "Follows your device's light or dark mode." }
        if self == .highContrast { return "Always available for low vision." }
        return nil
    }

    /// The kit's palette behind this choice. Teal & Coral Light and Dark are Teal & Coral
    /// pinned to one mode.
    var palette: Palette {
        switch self {
        case .tealCoral, .tealCoralLight, .tealCoralDark: .tealCoral
        case .sageSand: .sageSand
        case .indigoPeach: .indigoPeach
        case .sageCoral: .sageCoral
        case .highContrast: .highContrast
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

    /// Ids saved before the 2026 redesign, mapped to the theme that took their place
    /// (same unlock, except Ember: its slot went to the always-available High contrast).
    private static let legacyIDs: [String: ThemeChoice] = [
        "paper": .tealCoral, "slate": .sageSand, "sand": .indigoPeach, "midnight": .sageCoral, "ember": .highContrast,
    ]

    static func migrateSavedChoice(in defaults: UserDefaults = .standard) {
        guard let saved = defaults.string(forKey: PreferenceKey.theme), let theme = legacyIDs[saved] else { return }
        defaults.set(theme.rawValue, forKey: PreferenceKey.theme)
    }
}

enum TileStyle: String, Reward {
    case plain, circle, outline

    var title: LocalizedStringResource {
        switch self {
        case .plain: "Plain"
        case .circle: "Circle"
        case .outline: "Outline"
        }
    }

    var unlockedBy: Achievement? {
        switch self {
        case .plain: nil
        case .circle: .cleanSlate
        case .outline: .stageFive
        }
    }
}

enum NumberFont: String, Reward {
    case rounded, serif

    var title: LocalizedStringResource {
        switch self {
        case .rounded: "SF Rounded"
        case .serif: "New York"
        }
    }

    var unlockedBy: Achievement? { self == .serif ? .habit : nil }

    var design: Font.Design { self == .serif ? .serif : .rounded }
}

enum ClearEffect: String, Reward {
    case outline, wave

    var title: LocalizedStringResource {
        switch self {
        case .outline: "Outline"
        case .wave: "Wave"
        }
    }

    var unlockedBy: Achievement? { self == .wave ? .sweeper : nil }
}

enum SoundPack: String, Reward {
    case soft, marimba

    var title: LocalizedStringResource {
        switch self {
        case .soft: "Soft"
        case .marimba: "Marimba"
        }
    }

    var unlockedBy: Achievement? { self == .marimba ? .monotone : nil }
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

/// The player's chosen cosmetics for the board, read by every screen. The colors are the
/// kit's `\.quietTheme`.
struct Appearance {
    var tileStyle: TileStyle = .plain
    var numberFont: NumberFont = .rounded
    var clearEffect: ClearEffect = .outline
    var largerNumbers = false
}

extension EnvironmentValues {
    @Entry var appearance = Appearance()
}

/// Storage keys for preferences (UserDefaults).
enum PreferenceKey {
    static let theme = "theme"
    static let tileStyle = "tileStyle"
    static let numberFont = "numberFont"
    static let clearEffect = "clearEffect"
    static let soundPack = "soundPack"
    static let appIcon = "appIcon"
    static let soundEnabled = "soundEnabled"
    static let hapticsEnabled = "hapticsEnabled"
    static let largerNumbers = "largerNumbers"
    /// The tutorial was played or skipped. Cleared by a reset, like a fresh install.
    static let tutorialSeen = "tutorialSeen"
    /// Set by a reset until the iCloud copy and achievements are cleared too.
    static let pendingCloudReset = "pendingCloudReset"

    /// Cosmetic choices, cleared by a reset.
    static let rewards = [theme, tileStyle, numberFont, clearEffect, soundPack, appIcon]
}
