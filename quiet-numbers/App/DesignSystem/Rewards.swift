import QuietNumbersCore
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

    /// Teal & Coral follows the system, or stays light or dark whatever the device uses;
    /// the others have a single mode of their own.
    var theme: Theme {
        switch self {
        case .tealCoral: Theme(assetPrefix: "TealCoral", colorScheme: nil)
        case .tealCoralLight: Theme(assetPrefix: "TealCoral", colorScheme: .light)
        case .tealCoralDark: Theme(assetPrefix: "TealCoral", colorScheme: .dark)
        case .sageSand: Theme(assetPrefix: "SageSand", colorScheme: .light)
        case .indigoPeach: Theme(assetPrefix: "IndigoPeach", colorScheme: .dark)
        case .sageCoral: Theme(assetPrefix: "SageCoral", colorScheme: .light)
        case .highContrast: Theme(assetPrefix: "HighContrast", colorScheme: .light, isHighContrast: true)
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

/// Colors for a theme, by role. Values live in the asset catalog (`scripts/theme-colors.py`).
struct Theme {
    /// Screen background.
    let background: Color
    /// Cards, list rows, round buttons.
    let surface: Color
    /// Secondary buttons, segment tracks, switches when off.
    let surface2: Color
    /// Text and board numbers.
    let ink: Color
    /// Secondary text.
    let muted: Color
    /// Main buttons, selection, bar icons.
    let primary: Color
    /// Text on `primary`.
    let onPrimary: Color
    /// Numbers added with +, streaks, praise.
    let accent: Color
    /// Cleared numbers, still faintly visible.
    let ghost: Color
    let separator: Color
    /// Single-mode themes force their scheme so system controls match.
    let colorScheme: ColorScheme?
    /// Surfaces get a border and added numbers are underlined, so nothing depends on color alone.
    let isHighContrast: Bool

    init(assetPrefix prefix: String, colorScheme: ColorScheme?, isHighContrast: Bool = false) {
        background = Color("\(prefix)Background")
        surface = Color("\(prefix)Surface")
        surface2 = Color("\(prefix)Surface2")
        ink = Color("\(prefix)Ink")
        muted = Color("\(prefix)Muted")
        primary = Color("\(prefix)Primary")
        onPrimary = Color("\(prefix)OnPrimary")
        accent = Color("\(prefix)Accent")
        ghost = Color("\(prefix)Ghost")
        separator = Color("\(prefix)Separator")
        self.colorScheme = colorScheme
        self.isHighContrast = isHighContrast
    }

    /// Text on `accent` (the background reads well on every theme's accent).
    var onAccent: Color { background }
}

/// The player's chosen cosmetics, read by every screen.
struct Appearance {
    var theme: Theme = ThemeChoice.tealCoral.theme
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
