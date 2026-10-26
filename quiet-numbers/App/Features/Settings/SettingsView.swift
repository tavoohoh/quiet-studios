import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKey.soundEnabled) private var soundEnabled = true
    @AppStorage(PreferenceKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(PreferenceKey.largerNumbers) private var largerNumbers = false
    @Environment(\.appearance) private var appearance
    @Environment(AppModel.self) private var app
    @State private var confirmsReset = false

    var body: some View {
        Form {
            Section {
                Toggle("Sound", isOn: $soundEnabled)
                #if os(iOS)
                Toggle("Haptics", isOn: $hapticsEnabled)
                #endif
                Toggle("Larger numbers", isOn: $largerNumbers)
            }
            .listRowBackground(Rectangle().fill(appearance.theme.surface))

            Section("Privacy") {
                Text("Quiet Numbers doesn't collect any data. Your games, streaks and achievements stay on this device. If you sign in to Game Center, your scores and achievements are shared with Apple's Game Center and your progress is saved in your iCloud.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Rectangle().fill(appearance.theme.surface))

            Section {
                Button("Reset Progress…", role: .destructive) { confirmsReset = true }
                    .accessibilityIdentifier("resetProgress")
            } footer: {
                Text("Deletes games, daily results, streaks, achievements and unlocked rewards, here and in iCloud.")
            }
            .listRowBackground(Rectangle().fill(appearance.theme.surface))

            Section {
                LabeledContent("Version", value: Self.version)
            }
            .listRowBackground(Rectangle().fill(appearance.theme.surface))
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(appearance.theme.background)
        .navigationTitle(Text("Settings"))
        .confirmationDialog("Reset all progress?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive, action: reset)
        } message: {
            Text("Your games, daily challenge results, streaks, achievements and unlocked rewards will be deleted on this device and in iCloud. Scores already on Game Center leaderboards stay there. This can't be undone.")
        }
    }

    private func reset() {
        app.resetProgress()
        #if os(iOS)
        // The gold icon is a reward too.
        if UIApplication.shared.alternateIconName != nil {
            UIApplication.shared.setAlternateIconName(nil)
        }
        #endif
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
