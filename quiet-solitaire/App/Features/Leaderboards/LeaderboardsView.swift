import QuietCore
import QuietUI
import SwiftUI

/// Minimal leaderboards: pick a board, Global or Friends. Game Center does the ranking.
struct LeaderboardsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.quietTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var board = Leaderboard.daily
    @State private var friendsOnly = false
    @State private var state = LoadState.loading
    /// A friend tapped on the Friends tab: their profile.
    @State private var friend: GameCenterService.Entry?

    private enum LoadState {
        case loading
        case loaded(local: GameCenterService.Entry?, top: [GameCenterService.Entry])
        case failed
    }

    var body: some View {
        VStack(spacing: 10) {
            Segments(selection: $board, options: [
                (.daily, "Today"),
                (.bestScore, "Best score"),
                (.longestStreak, "Streak"),
            ])
            Segments(selection: $friendsOnly, options: [(false, "Global"), (true, "Friends")])
            content
                .padding(.top, 6)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .frame(maxWidth: Layout.column(sizeClass))
        .frame(maxWidth: .infinity)
        .screen(Text("Leaderboards"))
        .task(id: "\(board.rawValue)-\(friendsOnly)-\(isSignedIn)") { await load() }
        .friendProfile($friend)
    }

    @ViewBuilder
    private var content: some View {
        if !isSignedIn {
            SignedOutCard { app.gameCenter.signIn() }
        } else {
            switch state {
            case .loading:
                ProgressView()
                    .tint(theme.primary)
                    .padding(.top, 40)
            case .failed:
                Message(systemImage: "wifi.slash", title: "Couldn't load", text: "Check your connection and try again.")
            case .loaded(let local, let top):
                if top.isEmpty {
                    Message(systemImage: "trophy", title: "No scores yet", text: nil)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            EntryList(entries: top, showsTime: board == .daily, onSelect: friendsOnly ? { friend = $0 } : nil)
                            if let local, !top.contains(where: \.isLocalPlayer) {
                                EntryList(entries: [local], showsTime: board == .daily)
                            }
                            Text("Scores from Game Center · updated just now")
                                .font(.footnote)
                                .foregroundStyle(theme.muted)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private var isSignedIn: Bool {
        #if DEBUG
        if DemoData.isActive { return true }
        #endif
        return app.gameCenter.isAuthenticated
    }

    private func load() async {
        #if DEBUG
        if DemoData.isActive {
            let demo = DemoData.leaderboard(board)
            state = .loaded(local: demo.local, top: demo.top)
            return
        }
        #endif
        guard app.gameCenter.isAuthenticated else { return }
        state = .loading
        do {
            // Today's board breaks ties by time, faster first.
            let result = board == .daily
                ? try await app.gameCenter.dailyEntries(for: board.rawValue, friendsOnly: friendsOnly)
                : try await app.gameCenter.entries(for: board.rawValue, friendsOnly: friendsOnly)
            state = .loaded(local: result.local, top: result.top)
        } catch {
            state = .failed
        }
    }
}

private struct EntryList: View {
    let entries: [GameCenterService.Entry]
    let showsTime: Bool
    /// Friends tab: tapping someone else opens their profile.
    var onSelect: ((GameCenterService.Entry) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                if let onSelect, !entry.isLocalPlayer {
                    Button { onSelect(entry) } label: { EntryRow(entry: entry, showsTime: showsTime).contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Opens their profile"))
                } else {
                    EntryRow(entry: entry, showsTime: showsTime)
                }
            }
        }
        .padding(6)
        .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    }
}

private struct EntryRow: View {
    let entry: GameCenterService.Entry
    /// Today's board: the time that breaks ties, next to the score.
    let showsTime: Bool

    @Environment(\.quietTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.rank, format: .number)
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(medal?.text ?? theme.muted)
                .frame(width: 28, height: 28)
                .background { if let medal { Circle().fill(medal.fill) } }
            Text(verbatim: String(entry.name.prefix(1)).uppercased())
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Self.avatarColor(for: entry.name), in: Circle())
                .accessibilityHidden(true)
            Text(verbatim: entry.name)
                .fontWeight(entry.isLocalPlayer ? .heavy : .regular)
                .foregroundStyle(entry.isLocalPlayer ? theme.primary : theme.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            if showsTime, let seconds = GameCenterService.dailySeconds(of: entry) {
                Text(GameClock.string(seconds))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.muted)
            }
            Text(entry.score, format: .number)
                .font(.system(.title3, design: .rounded, weight: entry.isLocalPlayer ? .heavy : .medium).monospacedDigit())
                .foregroundStyle(entry.isLocalPlayer ? theme.primary : theme.ink)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .background {
            if entry.isLocalPlayer {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.primary.opacity(0.16))
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Top three: 1 accent, 2 primary, 3 muted.
    private var medal: (fill: Color, text: Color)? {
        switch entry.rank {
        case 1: return (theme.accent, theme.onAccent)
        case 2: return (theme.primary, theme.onPrimary)
        case 3: return (theme.muted, theme.background)
        default: return nil
        }
    }

    /// A stable, muted hue per name (FNV-1a, not `Hasher`, so it doesn't change between launches).
    private static func avatarColor(for name: String) -> Color {
        let hue = Double(FNV1a.hash(name) % 360) / 360
        return Color(hue: hue, saturation: 0.45, brightness: 0.55)
    }
}

/// Signed out: faded placeholder rows behind a card that points to Game Center.
private struct SignedOutCard: View {
    let onSignIn: () -> Void

    @Environment(\.quietTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ForEach([110, 80, 130, 90, 120, 70, 100, 85], id: \.self) { width in
                    HStack(spacing: 12) {
                        Circle().fill(theme.surface2).frame(width: 28, height: 28)
                        Circle().fill(theme.surface2).frame(width: 34, height: 34)
                        Capsule().fill(theme.surface2).frame(width: CGFloat(width), height: 12)
                        Spacer()
                        Capsule().fill(theme.surface2).frame(width: 36, height: 12)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 50)
                }
            }
            .padding(6)
            .opacity(0.6)
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Image(systemName: "trophy")
                    .font(.title2)
                    .foregroundStyle(theme.primary)
                    .frame(width: 56, height: 56)
                    .background(theme.primary.opacity(0.14), in: Circle())
                Text("Play with friends")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.ink)
                Text("Sign in to Game Center in Settings to see leaderboards. Your progress is saved on this device either way.")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings", action: onSignIn)
                    .buttonStyle(CapsuleButtonStyle())
                    .padding(.top, 6)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous), fill: theme.background) }
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.horizontal, 16)
            .padding(.top, 110)
        }
        .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    }
}

private struct Message: View {
    let systemImage: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey?

    @Environment(\.quietTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(theme.muted)
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.ink)
            if let text {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }
}
