import QuietNumbersCore
import SwiftUI

/// Achievements and the cosmetics they unlock. Locked items show how to get them.
struct CollectionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.appearance) private var appearance
    @AppStorage(PreferenceKey.theme) private var theme = ThemeChoice.paper
    @AppStorage(PreferenceKey.tileStyle) private var tileStyle = TileStyle.plain
    @AppStorage(PreferenceKey.numberFont) private var numberFont = NumberFont.rounded
    @AppStorage(PreferenceKey.clearEffect) private var clearEffect = ClearEffect.outline
    @AppStorage(PreferenceKey.soundPack) private var soundPack = SoundPack.soft
    @AppStorage(PreferenceKey.appIcon) private var appIcon = AppIconChoice.standard

    var body: some View {
        List {
            RewardSection(title: "Theme", selection: $theme, progress: app.progress)
            RewardSection(title: "Tiles", selection: $tileStyle, progress: app.progress)
            RewardSection(title: "Numbers", selection: $numberFont, progress: app.progress)
            RewardSection(title: "Row clear", selection: $clearEffect, progress: app.progress)
            RewardSection(title: "Sound", selection: $soundPack, progress: app.progress)
            #if os(iOS)
            RewardSection(title: "App icon", selection: $appIcon, progress: app.progress)
                .onChange(of: appIcon) { setAppIcon(appIcon) }
            #endif
            Section("Achievements") {
                ForEach(Achievement.allCases, id: \.self) { achievement in
                    AchievementRow(achievement: achievement, progress: app.progress.progress(of: achievement))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(appearance.theme.background)
        .navigationTitle(Text("Collection"))
    }

    #if os(iOS)
    private func setAppIcon(_ choice: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != choice.iconName
        else { return }
        UIApplication.shared.setAlternateIconName(choice.iconName)
    }
    #endif
}

private struct RewardSection<R: Reward>: View {
    let title: LocalizedStringKey
    @Binding var selection: R
    let progress: PlayerProgress

    @Environment(\.appearance) private var appearance

    var body: some View {
        Section(title) {
            ForEach(Array(R.allCases), id: \.self) { item in
                let isUnlocked = item.isUnlocked(in: progress)
                Button {
                    selection = item
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            if !isUnlocked, let achievement = item.unlockedBy {
                                Text(achievement.condition)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if !isUnlocked {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                        } else if item == selection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isUnlocked)
                .accessibilityAddTraits(item == selection ? .isSelected : [])
                .listRowBackground(Rectangle().fill(appearance.theme.surface))
            }
        }
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let progress: Double

    @Environment(\.appearance) private var appearance

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: achievement.systemImage)
                .font(.title3)
                .frame(width: 32)
                .foregroundStyle(progress >= 1 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                Text(achievement.condition)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if progress > 0, progress < 1, achievement.target > 1 {
                    ProgressView(value: progress)
                }
            }
            Spacer()
            if progress >= 1 {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue(progress >= 1 ? Text("Unlocked") : Text(progress, format: .percent.precision(.fractionLength(0))))
        .listRowBackground(Rectangle().fill(appearance.theme.surface))
    }
}
