import QuietNumbersCore
import SwiftUI

/// Reads the player's choices and publishes them as `\.appearance`, tint and color scheme.
/// The theme's ink is applied where numbers are drawn, not app-wide, so system button
/// styles keep their own label colors.
/// A choice that isn't unlocked (e.g. restored on a new device) falls back to the default.
struct AppearanceRoot: ViewModifier {
    @Environment(AppModel.self) private var app
    @AppStorage(PreferenceKey.theme) private var theme = ThemeChoice.tealCoral
    @AppStorage(PreferenceKey.tileStyle) private var tileStyle = TileStyle.plain
    @AppStorage(PreferenceKey.numberFont) private var numberFont = NumberFont.rounded
    @AppStorage(PreferenceKey.clearEffect) private var clearEffect = ClearEffect.outline
    @AppStorage(PreferenceKey.largerNumbers) private var largerNumbers = false

    func body(content: Content) -> some View {
        let colors = available(theme, or: .tealCoral).theme
        content
            .environment(\.appearance, Appearance(
                theme: colors,
                tileStyle: available(tileStyle, or: .plain),
                numberFont: available(numberFont, or: .rounded),
                clearEffect: available(clearEffect, or: .outline),
                largerNumbers: largerNumbers
            ))
            .tint(colors.primary)
            .preferredColorScheme(colors.colorScheme)
    }

    private func available<R: Reward>(_ choice: R, or fallback: R) -> R {
        choice.isUnlocked(in: app.progress) ? choice : fallback
    }
}
