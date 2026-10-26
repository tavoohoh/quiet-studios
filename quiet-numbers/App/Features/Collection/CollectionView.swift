import QuietNumbersCore
import SwiftUI

/// Achievements and the cosmetics they unlock. Locked items show how to get them.
struct CollectionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.appearance) private var appearance
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(PreferenceKey.theme) private var theme = ThemeChoice.tealCoral
    @AppStorage(PreferenceKey.tileStyle) private var tileStyle = TileStyle.plain
    @AppStorage(PreferenceKey.numberFont) private var numberFont = NumberFont.rounded
    @AppStorage(PreferenceKey.clearEffect) private var clearEffect = ClearEffect.outline
    @AppStorage(PreferenceKey.soundPack) private var soundPack = SoundPack.soft
    @AppStorage(PreferenceKey.appIcon) private var appIcon = AppIconChoice.standard

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                RewardSection(title: "Theme", selection: $theme, progress: app.progress) { choice in
                    ThemeSwatch(theme: choice.theme)
                }
                RewardSection(title: "Tiles", selection: $tileStyle, progress: app.progress) { style in
                    TilePreview(style: style)
                }
                RewardSection(title: "Numbers", selection: $numberFont, progress: app.progress) { font in
                    Text(verbatim: "12")
                        .font(.system(size: 20, weight: .bold, design: font.design))
                        .foregroundStyle(appearance.theme.ink)
                        .frame(width: 36, alignment: .leading)
                }
                RewardSection(title: "Row clear", selection: $clearEffect, progress: app.progress)
                RewardSection(title: "Sound", selection: $soundPack, progress: app.progress)
                RewardSection(title: "App icon", selection: $appIcon, progress: app.progress)
                    .onChange(of: appIcon) { setAppIcon(appIcon) }
                GroupSection("Achievements") {
                    ForEach(Achievement.allCases, id: \.self) { achievement in
                        AchievementRow(achievement: achievement, progress: app.progress.progress(of: achievement))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: Layout.column(sizeClass))
            .frame(maxWidth: .infinity)
        }
        .screen(Text("Collection"))
    }

    private func setAppIcon(_ choice: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != choice.iconName
        else { return }
        UIApplication.shared.setAlternateIconName(choice.iconName)
    }
}

private struct RewardSection<R: Reward, Preview: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: R
    let progress: PlayerProgress
    @ViewBuilder let preview: (R) -> Preview

    @Environment(\.appearance) private var appearance

    var body: some View {
        GroupSection(title) {
            ForEach(Array(R.allCases), id: \.self) { item in
                let isUnlocked = item.isUnlocked(in: progress)
                Button {
                    selection = item
                } label: {
                    HStack(spacing: 14) {
                        preview(item)
                            .opacity(isUnlocked ? 1 : 0.5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .foregroundStyle(isUnlocked ? appearance.theme.ink : appearance.theme.muted)
                            if let detail = detail(for: item, isUnlocked: isUnlocked) {
                                Text(detail)
                                    .font(.subheadline)
                                    .foregroundStyle(appearance.theme.muted)
                            }
                        }
                        Spacer(minLength: 8)
                        if !isUnlocked {
                            Image(systemName: "lock")
                                .foregroundStyle(appearance.theme.muted)
                        } else if item == selection {
                            Image(systemName: "checkmark")
                                .fontWeight(.bold)
                                .foregroundStyle(appearance.theme.primary)
                        }
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isUnlocked)
                .accessibilityLabel(Text(item.title))
                .accessibilityValue(detail(for: item, isUnlocked: isUnlocked).map { Text($0) } ?? Text(verbatim: ""))
                .accessibilityAddTraits(item == selection ? .isSelected : [])
            }
        }
    }

    private func detail(for item: R, isUnlocked: Bool) -> LocalizedStringResource? {
        if let theme = item as? ThemeChoice, let note = theme.note { return note }
        guard !isUnlocked, let achievement = item.unlockedBy else { return nil }
        return achievement.condition
    }
}

extension RewardSection where Preview == EmptyView {
    init(title: LocalizedStringKey, selection: Binding<R>, progress: PlayerProgress) {
        self.init(title: title, selection: selection, progress: progress) { _ in EmptyView() }
    }
}

/// A theme's primary and accent, as two overlapping dots.
private struct ThemeSwatch: View {
    let theme: Theme

    @Environment(\.appearance) private var appearance
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .leading) {
            Circle().fill(theme.primary).frame(width: 24, height: 24)
            Circle().fill(theme.accent).frame(width: 24, height: 24)
                .overlay { Circle().stroke(appearance.theme.surface, lineWidth: 2) }
                .offset(x: 12)
        }
        // Single-mode themes show their own colors whatever the current scheme.
        .environment(\.colorScheme, theme.colorScheme ?? colorScheme)
        .frame(width: 36, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// A "7" drawn with a tile style.
private struct TilePreview: View {
    let style: TileStyle

    @Environment(\.appearance) private var appearance

    var body: some View {
        Text(verbatim: "7")
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .foregroundStyle(appearance.theme.ink)
            .frame(width: 34, height: 34)
            .background {
                switch style {
                case .plain: EmptyView()
                case .circle: Circle().fill(appearance.theme.surface2)
                case .outline: Circle().strokeBorder(appearance.theme.muted, lineWidth: 1.5)
                }
            }
            .accessibilityHidden(true)
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
                .frame(width: 36)
                .foregroundStyle(progress >= 1 ? appearance.theme.primary : appearance.theme.muted)
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(appearance.theme.ink)
                Text(achievement.condition)
                    .font(.subheadline)
                    .foregroundStyle(appearance.theme.muted)
                if progress > 0, progress < 1, achievement.target > 1 {
                    ProgressView(value: progress)
                        .tint(appearance.theme.primary)
                }
            }
            Spacer(minLength: 8)
            if progress >= 1 {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(appearance.theme.primary)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityValue(progress >= 1 ? Text("Unlocked") : Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}
