import QuietUI
import SwiftUI

/// Reads the player's choices and publishes them as `\.quietTheme`, `\.appearance`, tint and
/// color scheme. A choice that isn't unlocked (e.g. restored on a new device) falls back to
/// the default.
struct AppearanceRoot: ViewModifier {
    @Environment(AppModel.self) private var app
    @AppStorage(PreferenceKey.board) private var board = BoardChoice.tealCoral
    @AppStorage(PreferenceKey.deck) private var deck = DeckStyle.quiet
    @AppStorage(PreferenceKey.back) private var back = CardBack.theme
    @AppStorage(PreferenceKey.victory) private var victory = VictoryEffect.fireworks
    @AppStorage(PreferenceKey.leftHanded) private var leftHanded = false

    func body(content: Content) -> some View {
        let theme = available(board, or: .tealCoral).theme
        content
            .environment(\.quietTheme, theme)
            .environment(\.appearance, Appearance(
                deck: available(deck, or: .quiet),
                back: available(back, or: .theme),
                victory: available(victory, or: .fireworks),
                leftHanded: leftHanded
            ))
            .tint(theme.primary)
            .preferredColorScheme(theme.colorScheme)
    }

    private func available<R: Reward>(_ choice: R, or fallback: R) -> R {
        choice.isUnlocked(in: app.progress) ? choice : fallback
    }
}
