import QuietUI
import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKey.soundEnabled) private var soundEnabled = true
    @AppStorage(PreferenceKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(PreferenceKey.tapToMove) private var tapToMove = true
    @AppStorage(PreferenceKey.winnableOnly) private var winnableOnly = true
    @AppStorage(PreferenceKey.leftHanded) private var leftHanded = false
    @Environment(\.quietTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppModel.self) private var app
    @State private var confirmsReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                GroupSection("Play") {
                    Toggle("Sound", isOn: $soundEnabled)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                    Toggle(isOn: $tapToMove) { ToggleLabel(title: "Tap to move", detail: "A tapped card goes to its best place.") }
                    Toggle(isOn: $winnableOnly) { ToggleLabel(title: "Only winnable deals", detail: "Every classic deal can be won.") }
                    Toggle(isOn: $leftHanded) { ToggleLabel(title: "Left-handed", detail: "Stock and waste on the left.") }
                }
                .toggleStyle(ThemedToggleStyle())

                GroupSection("Account") {
                    Button {
                        if app.gameCenter.isAuthenticated { app.gameCenter.showDashboard() } else { app.gameCenter.signIn() }
                    } label: {
                        SettingsRow(title: Text("Game Center"), detail: gameCenterStatus)
                    }
                    NavigationLink {
                        HowToPlayView()
                    } label: {
                        SettingsRow(title: Text("How to play"))
                    }
                }
                .buttonStyle(.plain)

                GroupSection("Privacy") {
                    Text("Quiet Solitaire doesn't collect any data. Your games, streaks and achievements stay on this device. If you sign in to Game Center, your scores and achievements are shared with Apple's Game Center and your progress is saved in your iCloud.")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    GroupSection {
                        Button { confirmsReset = true } label: {
                            Text("Reset Progress…")
                                .foregroundStyle(theme.accent)
                                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("resetProgress")
                    }
                    Text("Deletes games, daily results, streaks, achievements and unlocked rewards, here and in iCloud.")
                        .font(.footnote)
                        .foregroundStyle(theme.muted)
                        .padding(.horizontal, 16)
                }

                GroupSection {
                    HStack {
                        Text("Version").foregroundStyle(theme.ink)
                        Spacer()
                        Text(verbatim: Self.version).foregroundStyle(theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: Layout.column(sizeClass))
            .frame(maxWidth: .infinity)
        }
        .screen(Text("Settings"))
        .confirmationDialog("Reset all progress?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive, action: reset)
        } message: {
            Text("Your games, daily challenge results, streaks, achievements and unlocked rewards will be deleted on this device and in iCloud. Scores already on Game Center leaderboards stay there. This can't be undone.")
        }
    }

    private var gameCenterStatus: Text {
        if let name = app.gameCenter.playerName { return Text("Signed in as \(name)") }
        return Text("Not signed in")
    }

    private func reset() {
        app.resetProgress()
        // The gold icon is a reward too.
        if UIApplication.shared.alternateIconName != nil {
            UIApplication.shared.setAlternateIconName(nil)
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

private struct ToggleLabel: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    @Environment(\.quietTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(theme.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(theme.muted)
        }
        .padding(.vertical, 8)
    }
}

/// Title, optional detail under it, and a chevron.
private struct SettingsRow: View {
    let title: Text
    var detail: Text?

    @Environment(\.quietTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                title.foregroundStyle(theme.ink)
                if let detail {
                    detail
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                }
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.bold))
                .foregroundStyle(theme.muted)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// The rules, short.
struct HowToPlayView: View {
    @Environment(\.quietTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                rule("rectangle.stack", "Goal", "Move all 52 cards to the four foundations, one per suit, from ace to king.")
                rule("arrow.down.right", "Columns", "Build down in alternating colors: a red 6 on a black 7. Move a whole run at once. Only a king goes on an empty column.")
                rule("arrow.clockwise", "Stock", "Tap the stock to turn one card. When it runs out, tap again to turn the waste over. As many times as you like.")
                rule("hand.tap", "Tap or drag", "Tap a card to send it to its best place, or drag it where you want.")
                rule("lightbulb", "Hints", "A hint shows a move that leads to a win when there is one. Each hint costs 10 points.")
                rule("star", "Score", "5 for a card from the waste to a column, 10 for each card on a foundation, 5 for each card turned over. Win in 100 moves or fewer for a 500 bonus.")
                rule("calendar", "Daily challenge", "One deal for everyone each day, always winnable. Easy on Monday, expert on Sunday.")
            }
            .padding(20)
            .frame(maxWidth: Layout.column(sizeClass))
            .frame(maxWidth: .infinity)
        }
        .screen(Text("How to play"))
    }

    private func rule(_ systemImage: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(theme.primary)
                .frame(width: 44, height: 44)
                .background(theme.surface2, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(theme.ink)
                Text(text).font(.subheadline).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
