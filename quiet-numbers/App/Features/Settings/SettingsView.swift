import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKey.soundEnabled) private var soundEnabled = true
    @AppStorage(PreferenceKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(PreferenceKey.largerNumbers) private var largerNumbers = false
    @Environment(\.appearance) private var appearance
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppModel.self) private var app
    @State private var confirmsReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                GroupSection("Play") {
                    Toggle("Sound", isOn: $soundEnabled)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                    Toggle("Larger numbers", isOn: $largerNumbers)
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
                    Text("Quiet Numbers doesn't collect any data. Your games, streaks and achievements stay on this device. If you sign in to Game Center, your scores and achievements are shared with Apple's Game Center and your progress is saved in your iCloud.")
                        .font(.subheadline)
                        .foregroundStyle(appearance.theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    GroupSection {
                        Button { confirmsReset = true } label: {
                            Text("Reset Progress…")
                                .foregroundStyle(appearance.theme.accent)
                                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("resetProgress")
                    }
                    Text("Deletes games, daily results, streaks, achievements and unlocked rewards, here and in iCloud.")
                        .font(.footnote)
                        .foregroundStyle(appearance.theme.muted)
                        .padding(.horizontal, 16)
                }

                GroupSection {
                    HStack {
                        Text("Version").foregroundStyle(appearance.theme.ink)
                        Spacer()
                        Text(verbatim: Self.version).foregroundStyle(appearance.theme.muted)
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

/// Title, optional detail under it, and a chevron.
private struct SettingsRow: View {
    let title: Text
    var detail: Text?

    @Environment(\.appearance) private var appearance

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                title.foregroundStyle(appearance.theme.ink)
                if let detail {
                    detail
                        .font(.subheadline)
                        .foregroundStyle(appearance.theme.muted)
                }
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.bold))
                .foregroundStyle(appearance.theme.muted)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// The rules in a few lines.
private struct HowToPlayView: View {
    @Environment(\.appearance) private var appearance
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                rule("equal", Text("Match two equal numbers, or two that add up to 10."))
                rule("arrow.up.left.and.arrow.down.right", Text("They can touch, or be in a straight line (across, down or diagonal) with only cleared cells between them. The last number of a row also connects to the first of the next."))
                rule("plus", Text("Out of pairs? Tap + to copy the numbers left to the end of the board. You get 5 per board."))
                rule("rectangle.compress.vertical", Text("Clear a row for 10 points, and the whole board to reach the next stage."))
                rule("lightbulb", Text("A hint shows a pair for 3 points."))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: Layout.column(sizeClass))
            .frame(maxWidth: .infinity)
        }
        .screen(Text("How to play"))
    }

    private func rule(_ systemImage: String, _ text: Text) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(appearance.theme.primary)
                .frame(width: 28)
            text
                .foregroundStyle(appearance.theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .card()
    }
}
