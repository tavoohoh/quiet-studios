import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKey.soundEnabled) private var soundEnabled = true
    @AppStorage(PreferenceKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(PreferenceKey.largerNumbers) private var largerNumbers = false
    @Environment(\.appearance) private var appearance

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
                Text("Quiet Numbers doesn't collect any data. Your games, streaks and achievements stay on this device. If you sign in to Game Center, your scores and achievements are shared with Apple's Game Center.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
