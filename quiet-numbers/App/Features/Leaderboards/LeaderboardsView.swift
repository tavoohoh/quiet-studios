import SwiftUI

/// Minimal leaderboards: pick a board, Global or Friends. Game Center does the ranking.
struct LeaderboardsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.appearance) private var appearance
    @State private var board = GameCenterService.Leaderboard.daily
    @State private var friendsOnly = false
    @State private var state = LoadState.loading

    private enum LoadState {
        case loading
        case loaded(local: GameCenterService.Entry?, top: [GameCenterService.Entry])
        case failed
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Leaderboard", selection: $board) {
                Text("Today").tag(GameCenterService.Leaderboard.daily)
                Text("Best score").tag(GameCenterService.Leaderboard.bestScore)
                Text("Streak").tag(GameCenterService.Leaderboard.longestStreak)
            }
            .pickerStyle(.segmented)
            Picker("Players", selection: $friendsOnly) {
                Text("Global").tag(false)
                Text("Friends").tag(true)
            }
            .pickerStyle(.segmented)

            content
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding()
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(appearance.theme.background)
        .navigationTitle(Text("Leaderboards"))
        .task(id: "\(board.rawValue)-\(friendsOnly)-\(app.gameCenter.isAuthenticated)") { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if !app.gameCenter.isAuthenticated {
            ContentUnavailableView {
                Label("Game Center", systemImage: "person.crop.circle")
            } description: {
                Text("Sign in to Game Center in Settings to see leaderboards. Your progress is saved on this device either way.")
            }
        } else {
            switch state {
            case .loading:
                ProgressView()
                    .padding(.top, 40)
            case .failed:
                ContentUnavailableView {
                    Label("Couldn't load", systemImage: "wifi.slash")
                } description: {
                    Text("Check your connection and try again.")
                }
            case .loaded(let local, let top):
                if top.isEmpty {
                    ContentUnavailableView {
                        Label("No scores yet", systemImage: "trophy")
                    }
                } else {
                    List {
                        ForEach(top) { EntryRow(entry: $0) }
                        if let local, !top.contains(where: \.isLocalPlayer) {
                            Section { EntryRow(entry: local) }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }

    private func load() async {
        guard app.gameCenter.isAuthenticated else { return }
        state = .loading
        do {
            let result = try await app.gameCenter.entries(for: board, friendsOnly: friendsOnly)
            state = .loaded(local: result.local, top: result.top)
        } catch {
            state = .failed
        }
    }
}

private struct EntryRow: View {
    let entry: GameCenterService.Entry
    @Environment(\.appearance) private var appearance

    var body: some View {
        HStack(spacing: 14) {
            Text(entry.rank, format: .number)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, alignment: .trailing)
            Text(verbatim: entry.name)
                .fontWeight(entry.isLocalPlayer ? .semibold : .regular)
                .lineLimit(1)
            Spacer()
            Text(entry.score, format: .number)
                .font(.body.monospacedDigit())
        }
        .foregroundStyle(entry.isLocalPlayer ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        .listRowBackground(Rectangle().fill(appearance.theme.surface))
    }
}
