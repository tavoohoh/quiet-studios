import QuietUI
import SwiftUI

/// Reads the player's choices and publishes them as `\.quietTheme`, `\.appearance`, tint and
/// color scheme. A choice that isn't unlocked (e.g. restored on a new device) falls back to
/// the default.
struct AppearanceRoot: ViewModifier {
    @Environment(AppModel.self) private var app
    @AppStorage(PreferenceKey.board) private var board = BoardChoice.tealCoral
    @AppStorage(PreferenceKey.digits) private var digits = DigitStyle.rounded
    @AppStorage(PreferenceKey.notes) private var notes = NotesStyle.plain
    @AppStorage(PreferenceKey.highlight) private var highlight = HighlightStyle.full
    @AppStorage(PreferenceKey.victory) private var victory = VictoryEffect.fireworks
    @AppStorage(PreferenceKey.largeDigits) private var largeDigits = false
    @AppStorage(PreferenceKey.showsMistakes) private var showsMistakes = true

    func body(content: Content) -> some View {
        let theme = available(board, or: .tealCoral).theme
        content
            .environment(\.quietTheme, theme)
            .environment(\.appearance, Appearance(
                digits: available(digits, or: .rounded),
                notes: available(notes, or: .plain),
                highlight: available(highlight, or: .full),
                victory: available(victory, or: .fireworks),
                largeDigits: largeDigits,
                showsMistakes: showsMistakes
            ))
            .tint(theme.primary)
            .preferredColorScheme(theme.colorScheme)
    }

    private func available<R: Reward>(_ choice: R, or fallback: R) -> R {
        choice.isUnlocked(in: app.progress) ? choice : fallback
    }
}
