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
    case paper, slate, sand, midnight, ember

    var title: LocalizedStringResource {
        switch self {
        case .paper: "Paper"
        case .slate: "Slate"
        case .sand: "Sand"
        case .midnight: "Midnight"
        case .ember: "Ember"
        }
    }

    var unlockedBy: Achievement? {
        switch self {
        case .paper: nil
        case .slate: .noHelp
        case .sand: .consistency
        case .midnight: .nightOwl
        case .ember: .inTheRed
        }
    }

    var theme: Theme {
        switch self {
        case .paper:
            Theme(
                background: AnyShapeStyle(.background),
                surface: AnyShapeStyle(.background.secondary),
                ink: AnyShapeStyle(.primary),
                accent: .accentColor,
                colorScheme: nil
            )
        case .slate:
            Theme(background: .init(Color.slateBackground), surface: .init(Color.slateSurface),
                  ink: .init(Color.slateInk), accent: .slateAccent, colorScheme: .dark)
        case .sand:
            Theme(background: .init(Color.sandBackground), surface: .init(Color.sandSurface),
                  ink: .init(Color.sandInk), accent: .sandAccent, colorScheme: nil)
        case .midnight:
            Theme(background: .init(Color.midnightBackground), surface: .init(Color.midnightSurface),
                  ink: .init(Color.midnightInk), accent: .midnightAccent, colorScheme: .dark)
        case .ember:
            Theme(background: .init(Color.emberBackground), surface: .init(Color.emberSurface),
                  ink: .init(Color.emberInk), accent: .emberAccent, colorScheme: .dark)
        }
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

/// Colors for a theme. Paper uses the system's semantic styles.
struct Theme {
    let background: AnyShapeStyle
    let surface: AnyShapeStyle
    let ink: AnyShapeStyle
    let accent: Color
    /// Dark-only themes force dark mode so system controls match.
    let colorScheme: ColorScheme?
}

/// The player's chosen cosmetics, read by every screen.
struct Appearance {
    var theme: Theme = ThemeChoice.paper.theme
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
}
