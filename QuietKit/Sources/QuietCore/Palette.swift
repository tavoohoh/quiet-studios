/// The family's color themes, by role, as hex values (from the "Quiet Numbers · Diseño"
/// canvas, page 6). `QuietUI` turns them into colors; `PaletteTests` checks text contrast.
public enum Palette: String, CaseIterable, Codable, Sendable {
    case tealCoral, sageSand, indigoPeach, sageCoral, highContrast

    public enum Role: String, CaseIterable, Sendable {
        case background, surface, surface2, ink, muted, primary, onPrimary, accent, ghost, separator
        /// Red suits on cards (Quiet Solitaire). The accent, except where it doesn't read as red.
        case suitRed
    }

    public enum Mode: Sendable {
        /// Follows the system: light and dark values.
        case system
        case lightOnly
        case darkOnly
    }

    public var mode: Mode {
        switch self {
        case .tealCoral: .system
        case .sageSand, .sageCoral, .highContrast: .lightOnly
        case .indigoPeach: .darkOnly
        }
    }

    /// Surfaces get a border, so nothing depends on color alone.
    public var isHighContrast: Bool { self == .highContrast }

    /// (light, dark) hex. Single-mode palettes repeat the value.
    public func hex(_ role: Role) -> (light: String, dark: String) {
        let pair = Self.values[self]![role]!
        return (pair.0, pair.1 ?? pair.0)
    }

    private static let values: [Palette: [Role: (String, String?)]] = [
        .tealCoral: [
            .background: ("#F3F7F8", "#0F1A1D"), .surface: ("#FFFFFF", "#172629"), .surface2: ("#E3EEF0", "#1F3236"),
            .ink: ("#16201F", "#E8F1F2"), .muted: ("#5E6F72", "#8A9DA0"), .primary: ("#0E6B78", "#5BC2CF"),
            .onPrimary: ("#FFFFFF", "#062327"), .accent: ("#B9472F", "#FF9A85"), .ghost: ("#CFD8DA", "#2C3A3D"),
            .separator: ("#E3EAEC", "#263A3E"), .suitRed: ("#B9472F", "#FF9A85"),
        ],
        .sageSand: [
            .background: ("#F6F4EE", nil), .surface: ("#FFFFFF", nil), .surface2: ("#ECE9E0", nil),
            .ink: ("#1F2622", nil), .muted: ("#5F665F", nil), .primary: ("#387454", nil),
            .onPrimary: ("#FFFFFF", nil), .accent: ("#9A5B16", nil), .ghost: ("#D5D3CB", nil),
            .separator: ("#E6E2D8", nil),
            // The amber accent doesn't read as a red suit.
            .suitRed: ("#B4503A", nil),
        ],
        .indigoPeach: [
            .background: ("#13121F", nil), .surface: ("#1C1B2C", nil), .surface2: ("#27253A", nil),
            .ink: ("#ECEBF7", nil), .muted: ("#9593AE", nil), .primary: ("#9A98FF", nil),
            .onPrimary: ("#15133A", nil), .accent: ("#FFAE82", nil), .ghost: ("#302E44", nil),
            .separator: ("#2A2840", nil), .suitRed: ("#FFAE82", nil),
        ],
        .sageCoral: [
            .background: ("#F7F3EC", nil), .surface: ("#FFFFFF", nil), .surface2: ("#EFEAE0", nil),
            .ink: ("#1E2420", nil), .muted: ("#646A64", nil), .primary: ("#4D7157", nil),
            .onPrimary: ("#FFFFFF", nil), .accent: ("#B4503A", nil), .ghost: ("#D9D4CA", nil),
            .separator: ("#E8E2D6", nil), .suitRed: ("#B4503A", nil),
        ],
        .highContrast: [
            .background: ("#FFFFFF", nil), .surface: ("#FFFFFF", nil), .surface2: ("#E6EEF9", nil),
            .ink: ("#000000", nil), .muted: ("#3A3A3C", nil), .primary: ("#003F91", nil),
            .onPrimary: ("#FFFFFF", nil), .accent: ("#B85500", nil), .ghost: ("#B0B0B5", nil),
            .separator: ("#000000", nil),
            // A true red: the orange accent is too close to the black suits' contrast story.
            .suitRed: ("#B3001B", nil),
        ],
    ]
}

/// WCAG contrast between two `#RRGGBB` colors.
public enum Contrast {
    public static func ratio(_ a: String, _ b: String) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Red, green, blue in 0...1.
    public static func components(_ hex: String) -> (Double, Double, Double) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    private static func luminance(_ hex: String) -> Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let (r, g, b) = components(hex)
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private static func pow(_ x: Double, _ y: Double) -> Double { exp(y * log(x)) }
}

import Foundation
