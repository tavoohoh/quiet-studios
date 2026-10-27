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
        case tutorial
    }

    @Environment(AppModel.self) private var app
    @Environment(\.appearance) private var appearance
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    HomeMenu()
                    VStack(spacing: 14) {
                        Image(.homeIcon)
                            .resizable()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 84 * 0.225, style: .continuous))
                            .accessibilityHidden(true)
                        Text(verbatim: "Quiet Numbers")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                            .foregroundStyle(appearance.theme.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("Your 5-minute break.")
                            .font(.body)
                            .foregroundStyle(appearance.theme.muted)
                    }
                    .padding(.top, 40)
                    VStack(spacing: 12) {
                        DailyCard { path.append(.daily) }
                            .accessibilityIdentifier("daily")
                        if let stage = app.classicStage {
                            Button {
                                app.continueClassic()
                                path.append(.game)
                            } label: {
                                Text("Continue · Stage \(stage)")
                            }
                            .buttonStyle(CapsuleButtonStyle())
                            .accessibilityIdentifier("continue")
                        }
                        Button {
                            if app.needsTutorial {
                                path.append(.tutorial)
                            } else {
                                app.newClassic()
                                path.append(.game)
                            }
                        } label: {
                            Text("New Game")
                        }
                        .buttonStyle(CapsuleButtonStyle(isProminent: !app.hasClassicInProgress))
                    }
                    .padding(.top, 36)
                    StatsRow()
                        .padding(.top, 30)
                }
                .frame(maxWidth: Layout.buttons(sizeClass))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .background(appearance.theme.background)
            .toolbar(.hidden, for: .navigationBar)
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
                case .tutorial:
                    TutorialView(isFirstRun: true) {
                        app.finishTutorial()
                        app.newClassic()
                        path = [.game]
                    }
                }
            }
            .onChange(of: app.gameCenter.isAuthenticated, initial: true) { updateAccessPoint() }
            .onChange(of: path) { updateAccessPoint() }
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
                onSessionChange: { app.sessionChanged() },
                bestScore: kind == .classic ? app.progress.bestScore : nil
            )
            .id(ObjectIdentifier(game))
            .onDisappear { app.leftGame() }
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
            achievement.badge
                .resizable()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement unlocked")
                    .font(.caption)
                    .foregroundStyle(appearance.theme.muted)
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(appearance.theme.ink)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background { SurfaceShape(shape: Capsule()) }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
        .onAppear {
            AccessibilityNotification.Announcement(String(localized: "Achievement unlocked")).post()
        }
    }
}

/// Leaderboards, Collection and Settings, in a capsule at the top right.
private struct HomeMenu: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        HStack(spacing: 0) {
            item(.leaderboards, "Leaderboards", systemImage: "trophy", id: "leaderboards")
            item(.collection, "Collection", systemImage: "square.grid.2x2", id: "collection")
            item(.settings, "Settings", systemImage: "gearshape", id: "settings")
        }
        .padding(.horizontal, 6)
        .background { SurfaceShape(shape: Capsule()) }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 6)
    }

    private func item(_ route: HomeView.Route, _ title: LocalizedStringKey, systemImage: String, id: String) -> some View {
        NavigationLink(value: route) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(appearance.theme.primary)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(id)
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
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Challenge")
                        .font(.headline)
                        .foregroundStyle(appearance.theme.ink)
                    status
                        .font(.subheadline)
                        .foregroundStyle(appearance.theme.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if app.currentStreak > 0 {
                    Label {
                        Text(app.currentStreak, format: .number)
                            .font(.system(.title3, design: .rounded, weight: .heavy).monospacedDigit())
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(appearance.theme.accent)
                    .accessibilityLabel(Text("\(app.currentStreak)-day streak"))
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(appearance.theme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var status: Text {
        let today = app.todayKey
        if app.isDailyInProgress(today) { return Text("In progress") }
        guard let record = app.persistence.dailies[today] else { return Text("Not played yet") }
        let score = Text(record.score, format: .number)
        return record.isCompleted ? Text("Completed · \(score)") : Text("Played · \(score)")
    }
}

/// Totals already kept in the player's progress: best classic score, best daily streak, games.
private struct StatsRow: View {
    @Environment(AppModel.self) private var app
    @Environment(\.appearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your stats")
                .font(.subheadline.bold())
                .foregroundStyle(appearance.theme.muted)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                StatTile(value: app.progress.bestScore, label: "Best score")
                StatTile(value: app.longestStreak, label: "Top streak")
                StatTile(value: app.progress.gamesPlayed, label: "Games")
            }
        }
    }
}

private struct StatTile: View {
    let value: Int
    let label: LocalizedStringKey

    @Environment(\.appearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.stat)
                .foregroundStyle(appearance.theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.footnote)
                .foregroundStyle(appearance.theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
        .accessibilityElement(children: .combine)
    }
}
