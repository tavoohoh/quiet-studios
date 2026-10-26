import GameKit
import QuietNumbersCore
import SwiftUI

struct HomeView: View {
    enum Route: Hashable {
        case game
        case daily
        case collection
        case settings
        case leaderboards
    }

    @Environment(AppModel.self) private var app
    @Environment(\.appearance) private var appearance
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 40) {
                Spacer()
                Text(verbatim: "Quiet Numbers")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 12) {
                    DailyCard { path.append(.daily) }
                    if app.hasClassicInProgress {
                        Button {
                            app.continueClassic()
                            path.append(.game)
                        } label: {
                            Text("Continue").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button {
                        app.newClassic()
                        path.append(.game)
                    } label: {
                        Text("New Game").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .frame(maxWidth: 360)
                Spacer()
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(appearance.theme.background)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .game:
                    ActiveGameView()
                case .daily:
                    DailyChallengeView { dayKey in
                        app.playDaily(dayKey)
                        path.append(.game)
                    }
                case .collection:
                    CollectionView()
                case .settings:
                    SettingsView()
                case .leaderboards:
                    LeaderboardsView()
                }
            }
            .onChange(of: app.gameCenter.isAuthenticated, initial: true) { updateAccessPoint() }
            .onChange(of: path) { updateAccessPoint() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: Route.leaderboards) {
                        Label("Leaderboards", systemImage: "trophy")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: Route.collection) {
                        Label("Collection", systemImage: "square.grid.2x2")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: Route.settings) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
        #if DEBUG
        .onAppear(perform: startDebugGameIfRequested)
        #endif
    }

    /// Game Center's access point, only on Home and only when signed in.
    private func updateAccessPoint() {
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.isActive = app.gameCenter.isAuthenticated && path.isEmpty
    }

    #if DEBUG
    /// Screenshots and UI tests: `-startGame` opens a game right away;
    /// `-seedKey <text>` makes its board deterministic and
    /// `-boardValues 5,3,7,…` starts from exact numbers.
    private func startDebugGameIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-startGame"), path.isEmpty else { return }
        func value(after flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        let session = if let values = value(after: "-boardValues") {
            GameSession(values: values.split(separator: ",").compactMap { Int($0) }, seed: 0)
        } else if let key = value(after: "-seedKey") {
            GameSession(seed: FNV1a.hash(key))
        } else {
            GameSession(seed: .random(in: .min ... .max))
        }
        app.start(GameModel(session: session), as: .classic)
        path = [.game]
    }
    #endif
}

/// The game `AppModel` has on screen.
private struct ActiveGameView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if let game = app.activeGame, let kind = app.activeKind {
            GameView(
                model: game,
                kind: kind,
                onNewGame: { app.newClassic() },
                onSessionChange: { app.sessionChanged() }
            )
            .id(ObjectIdentifier(game))
            .overlay(alignment: .bottom) {
                if let achievement = app.pendingUnlocks.first {
                    UnlockBanner(achievement: achievement)
                        .id(achievement)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: achievement) {
                            try? await Task.sleep(for: .seconds(2.5))
                            withAnimation(.quiet) { app.dismissUnlock(achievement) }
                        }
                }
            }
            .animation(.quiet, value: app.pendingUnlocks)
        }
    }
}

/// "Achievement unlocked" toast during play.
private struct UnlockBanner: View {
    let achievement: Achievement
    @Environment(\.appearance) private var appearance

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(achievement.title)
                    .font(.headline)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(appearance.theme.surface, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
        .onAppear {
            AccessibilityNotification.Announcement(String(localized: "Achievement unlocked")).post()
        }
    }
}

/// Today's challenge and the streak, as the first thing on Home.
private struct DailyCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.appearance) private var appearance
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Challenge")
                        .font(.headline)
                    status
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if app.currentStreak > 0 {
                    Label {
                        Text(app.currentStreak, format: .number)
                    } icon: {
                        Image(systemName: "flame")
                    }
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.highlight)
                    .accessibilityLabel(Text("\(app.currentStreak)-day streak"))
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(appearance.theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var status: Text {
        let today = app.todayKey
        if app.isDailyInProgress(today) { return Text("In progress") }
        guard let record = app.persistence.dailies[today] else { return Text("Today's board is ready") }
        let score = Text(record.score, format: .number)
        return record.isCompleted ? Text("Completed · \(score)") : Text("Played · \(score)")
    }
}
