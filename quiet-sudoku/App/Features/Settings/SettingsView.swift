import QuietSudokuCore
import QuietUI
import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKey.soundEnabled) private var soundEnabled = true
    @AppStorage(PreferenceKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(PreferenceKey.showsMistakes) private var showsMistakes = true
    @AppStorage(PreferenceKey.largeDigits) private var largeDigits = false
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
                    Toggle(isOn: $showsMistakes) { ToggleLabel(title: "Show mistakes right away", detail: "Off: they're checked when the board is full. Each mistake costs the same either way.") }
                        .accessibilityIdentifier("showsMistakes")
                    Toggle(isOn: $largeDigits) { ToggleLabel(title: "Large digits", detail: "Bigger digits and notes on the board.") }
                }
                .toggleStyle(ThemedToggleStyle())

                GroupSection("Daily Challenge") {
                    DailyReminderToggle(reminders: app.reminders)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("dailyReminder")
                    #if DEBUG
                    if PendingReminders.isRequested { PendingReminders() }
                    #endif
                }

                GroupSection("Account") {
                    Button {
                        if app.gameCenter.isAuthenticated { app.gameCenter.showDashboard() } else { app.gameCenter.signIn() }
                    } label: {
                        SettingsRow(title: Text("Game Center"), detail: gameCenterStatus)
                    }
                    NavigationLink {
                        TutorialFromSettings()
                    } label: {
                        SettingsRow(title: Text("How to play"))
                    }
                    NavigationLink {
                        HowToPlayView()
                    } label: {
                        SettingsRow(title: Text("Rules"))
                    }
                    NavigationLink {
                        TechniquesView()
                    } label: {
                        SettingsRow(title: Text("Techniques"))
                    }
                }
                .buttonStyle(.plain)

                GroupSection("Privacy") {
                    Text("Quiet Sudoku doesn't collect any data. Your games, streaks and achievements stay on this device. If you sign in to Game Center, your scores and achievements are shared with Apple's Game Center and your progress is saved in your iCloud.")
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

/// "How to play" replays the tutorial and comes back here.
private struct TutorialFromSettings: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TutorialView(isFirstRun: false) {
            app.finishTutorial()
            dismiss()
        }
    }
}

/// The rules, short.
struct HowToPlayView: View {
    @Environment(\.quietTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                rule("square.grid.3x3", "Goal", "Fill the grid so every row, every column and every 3×3 box holds the digits 1 to 9 once each.")
                rule("hand.tap", "Play", "Tap a cell, then a digit. Digits in dark ink came with the puzzle and can't change.")
                rule("pencil", "Notes", "Turn on Notes to jot the digits that could go in a cell. A digit you place clears itself from the notes it sees.")
                rule("xmark.circle", "Mistakes", "A digit that isn't the solution's is a mistake and costs 20 points, shown right away or not. The game never ends: fix it and go on.")
                rule("lightbulb", "Hints", "A hint writes the next digit you can find by logic and explains why. Each hint costs 10 points.")
                rule("star", "Score", "10 to 30 points per digit, by level. Solve it for 500 more, doubled if you're fast.")
                rule("calendar", "Daily challenge", "One sudoku for everyone each day, with one solution and no guessing. Easy on Monday, expert on Sunday.")
            }
            .padding(20)
            .frame(maxWidth: Layout.column(sizeClass))
            .frame(maxWidth: .infinity)
        }
        .screen(Text("Rules"))
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

/// Every technique a hint can name, by level.
struct TechniquesView: View {
    @Environment(\.quietTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Every Quiet Sudoku can be solved with these, without guessing. A puzzle's level is the hardest one it needs. A house is a row, a column or a box.")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Difficulty.allCases, id: \.self) { level in
                    GroupSection(LocalizedStringKey(String(localized: level.title))) {
                        ForEach(Technique.allCases.filter { $0.difficulty == level }, id: \.self) { technique in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(technique.title).font(.headline).foregroundStyle(theme.ink)
                                Text(technique.explanation).font(.subheadline).foregroundStyle(theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: Layout.column(sizeClass))
            .frame(maxWidth: .infinity)
        }
        .screen(Text("Techniques"))
    }
}
