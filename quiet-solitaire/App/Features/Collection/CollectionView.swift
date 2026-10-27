import QuietCore
import QuietSolitaireCore
import QuietUI
import SwiftUI

/// Achievements and the cosmetics they unlock. Locked items show how to get them.
struct CollectionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.quietTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(PreferenceKey.board) private var board = BoardChoice.tealCoral
    @AppStorage(PreferenceKey.deck) private var deck = DeckStyle.quiet
    @AppStorage(PreferenceKey.back) private var back = CardBack.theme
    @AppStorage(PreferenceKey.victory) private var victory = VictoryEffect.gentle
    @AppStorage(PreferenceKey.appIcon) private var appIcon = AppIconChoice.standard

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                RewardSection(title: "Deck", selection: $deck, progress: app.progress) { style in
                    CardFace(card: Card(1, .hearts), deck: style, width: 30)
                }
                BackPicker(selection: $back, progress: app.progress)
                RewardSection(title: "Board", selection: $board, progress: app.progress) { choice in
                    PaletteSwatch(palette: choice.palette)
                }
                RewardSection(title: "Victory", selection: $victory, progress: app.progress)
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

    @Environment(\.quietTheme) private var theme

    var body: some View {
        GroupSection(title) {
            ForEach(Array(R.allCases), id: \.self) { item in
                let isUnlocked = item.isUnlocked(in: progress)
                Button {
                    selection = item
                } label: {
                    HStack(spacing: 14) {
                        preview(item)
                            .opacity(isUnlocked ? 1 : 0.4)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .foregroundStyle(isUnlocked ? theme.ink : theme.muted)
                            if let detail = detail(for: item, isUnlocked: isUnlocked) {
                                Text(detail)
                                    .font(.subheadline)
                                    .foregroundStyle(theme.muted)
                            }
                        }
                        Spacer(minLength: 8)
                        if !isUnlocked {
                            Image(systemName: "lock")
                                .foregroundStyle(theme.muted)
                        } else if item == selection {
                            Image(systemName: "checkmark")
                                .fontWeight(.bold)
                                .foregroundStyle(theme.primary)
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
        if let note = item.note { return note }
        guard !isUnlocked, let achievement = item.unlockedBy else { return nil }
        return achievement.isHidden ? "Hidden achievement." : achievement.condition
    }
}

extension RewardSection where Preview == EmptyView {
    init(title: LocalizedStringKey, selection: Binding<R>, progress: PlayerProgress) {
        self.init(title: title, selection: selection, progress: progress) { _ in EmptyView() }
    }
}

/// Card backs side by side; the chosen one ringed, locked ones faded.
private struct BackPicker: View {
    @Binding var selection: CardBack
    let progress: PlayerProgress

    @Environment(\.quietTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card back")
                .font(.subheadline.bold())
                .foregroundStyle(theme.muted)
                .padding(.horizontal, 16)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: 8) {
                ForEach(CardBack.allCases, id: \.self) { back in
                    let isUnlocked = back.isUnlocked(in: progress)
                    Button {
                        selection = back
                    } label: {
                        VStack(spacing: 8) {
                            CardBackView(back: back, width: 44)
                                .overlay {
                                    if back == selection {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(theme.primary, lineWidth: 2)
                                            .padding(-4)
                                    }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if !isUnlocked {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                            .foregroundStyle(theme.muted)
                                            .padding(4)
                                            .background(theme.surface, in: Circle())
                                            .offset(x: 6, y: 6)
                                    }
                                }
                                .opacity(isUnlocked ? 1 : 0.45)
                            Text(back.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isUnlocked ? theme.ink : theme.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isUnlocked)
                    .accessibilityLabel(Text(back.title))
                    .accessibilityValue(isUnlocked ? Text(verbatim: "") : Text(back.unlockedBy.map { $0.isHidden ? "Hidden achievement." : $0.condition } ?? ""))
                    .accessibilityAddTraits(back == selection ? .isSelected : [])
                }
            }
            .padding(16)
            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
        }
    }
}

/// A palette's primary and accent, as two overlapping dots.
private struct PaletteSwatch: View {
    let palette: Palette

    @Environment(\.quietTheme) private var current
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = Theme(palette)
        ZStack(alignment: .leading) {
            Circle().fill(theme.primary).frame(width: 24, height: 24)
            Circle().fill(theme.accent).frame(width: 24, height: 24)
                .overlay { Circle().stroke(current.surface, lineWidth: 2) }
                .offset(x: 12)
        }
        // Single-mode palettes show their own colors whatever the current scheme.
        .environment(\.colorScheme, theme.colorScheme ?? colorScheme)
        .frame(width: 36, alignment: .leading)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let progress: Double

    @Environment(\.quietTheme) private var theme

    var body: some View {
        let isUnlocked = progress >= 1
        let isSecret = achievement.isHidden && !isUnlocked
        HStack(spacing: 14) {
            Image(systemName: isSecret ? "questionmark" : achievement.systemImage)
                .font(.title3)
                .foregroundStyle(isUnlocked ? theme.onPrimary : theme.muted)
                .frame(width: 44, height: 44)
                .background(isUnlocked ? theme.primary : theme.surface2, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(isSecret ? "Hidden achievement" : achievement.title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text(isSecret ? "Keep playing to find it." : achievement.condition)
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                if progress > 0, progress < 1, achievement.target > 1 {
                    ProgressView(value: progress)
                        .tint(theme.primary)
                }
            }
            Spacer(minLength: 8)
            if isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(theme.primary)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isUnlocked ? Text("Unlocked") : Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}
