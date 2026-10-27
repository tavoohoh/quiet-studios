#if canImport(UIKit)
import QuietCore
import SwiftUI
import UIKit

/// Colors for a palette, by role. Single-mode palettes force their color scheme so system
/// controls match; Teal & Coral follows the system.
public struct Theme: Sendable {
    public let palette: Palette
    /// Screen background.
    public let background: Color
    /// Cards, list rows, round buttons.
    public let surface: Color
    /// Secondary buttons, segment tracks, switches when off.
    public let surface2: Color
    /// Text.
    public let ink: Color
    /// Secondary text.
    public let muted: Color
    /// Main buttons, selection, bar icons.
    public let primary: Color
    /// Text on `primary`.
    public let onPrimary: Color
    /// Streaks, praise, destructive rows.
    public let accent: Color
    /// Disabled and empty things, still faintly visible.
    public let ghost: Color
    public let separator: Color
    /// Red suits on card faces.
    public let suitRed: Color

    public init(_ palette: Palette) {
        self.palette = palette
        func color(_ role: Palette.Role) -> Color {
            let hex = palette.hex(role)
            let light = UIColor(hex: hex.light), dark = UIColor(hex: hex.dark)
            return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
        }
        background = color(.background)
        surface = color(.surface)
        surface2 = color(.surface2)
        ink = color(.ink)
        muted = color(.muted)
        primary = color(.primary)
        onPrimary = color(.onPrimary)
        accent = color(.accent)
        ghost = color(.ghost)
        separator = color(.separator)
        suitRed = color(.suitRed)
    }

    public var colorScheme: ColorScheme? {
        switch palette.mode {
        case .system: nil
        case .lightOnly: .light
        case .darkOnly: .dark
        }
    }

    public var isHighContrast: Bool { palette.isHighContrast }

    /// Text on `accent` (the background reads well on every palette's accent).
    public var onAccent: Color { background }
}

extension UIColor {
    convenience init(hex: String) {
        let (r, g, b) = Contrast.components(hex)
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension EnvironmentValues {
    /// The player's palette, read by every component.
    @Entry public var quietTheme = Theme(.tealCoral)
}
#endif
