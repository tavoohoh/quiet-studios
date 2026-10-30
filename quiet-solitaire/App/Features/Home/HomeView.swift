import GameKit
import QuietCore
import QuietSolitaireCore
import QuietUI
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
    @Environment(\.quietTheme) private var theme
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
                        Text(verbatim: "Quiet Solitaire")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                            .foregroundStyle(theme.ink)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text("Your 5-minute break.")
                            .font(.body)
                            .foregroundStyle(theme.muted)
                    }
                    .padding(.top, 40)
                    VStack(spacing: 12) {
                        DailyCard { path.append(.daily) }
                            .accessibilityIdentifier("daily")
                        if let moves = app.classicMoves {
                            Button {
                                Task {
                                    await app.continueClassic()
                                    openGame()
                                }
                            } label: {
                                Text("Continue · \(moves) moves")
                            }
                            .buttonStyle(CapsuleButtonStyle())
                            .accessibilityIdentifier("continue")
                        }
                        Button {
                            if app.needsTutorial {
                                path.append(.tutorial)
                            } else {
                                Task {
                                    if await app.newClassic() { openGame() }
                                }
                            }
                        } label: {
                            Text("New Game")
                        }
                        .buttonStyle(CapsuleButtonStyle(isProminent: !app.hasClassicInProgress))
                        .disabled(app.isPreparing)
                        .accessibilityIdentifier("newGame")
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
            .background(theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .game:
                    ActiveGameView()
                case .daily:
                    DailyChallengeView { dayKey in
                        Task {
                            await app.playDaily(dayKey)
                            openGame()
                        }
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
                        Task {
                            await app.newClassic()
                            path = [.game]
                        }
                    }
                }
            }
            .onChange(of: app.gameCenter.isAuthenticated, initial: true) { updateAccessPoint() }
            // After a first completed daily, back from the game: "Remind you at 7 PM?"
            .dailyReminderOffer(app.reminders, isPresented: Bindable(app).offersReminders)
            .onChange(of: path) { updateAccessPoint() }
        }
        #if DEBUG
        .onAppear(perform: startDebugGameIfRequested)
        #endif
    }

    /// Shows the game screen once, however many taps got here.
    private func openGame() {
        if path.last != .game { path.append(.game) }
    }

    /// Game Center's access point, only on Home and only when signed in.
    private func updateAccessPoint() {
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.isActive = app.gameCenter.isAuthenticated && path.isEmpty
    }

    #if DEBUG
    /// UI tests: `-startGame` opens a game right away; `-seedKey <text>` makes its deal
    /// deterministic; `-nearlyWon` starts one move from auto-complete.
    private func startDebugGameIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-startGame"), path.isEmpty else { return }
        func value(after flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        let session = if arguments.contains("-nearlyWon") {
            GameSession(state: DebugDeals.nearlyWon, elapsedSeconds: DemoData.clock)
        } else if arguments.contains("-lostDeal") {
            GameSession(state: DebugDeals.lost)
        } else {
            GameSession(seed: value(after: "-seedKey").map(FNV1a.hash) ?? .random(in: .min ... .max))
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
                bestScore: kind == .classic ? app.bestAtStart : nil,
                unlocked: app.unlockedThisGame,
                onNewGame: { Task { await app.newClassic() } },
                onRestart: { app.restart() }
            )
            .id(ObjectIdentifier(game))
            .onDisappear { app.leftGame() }
            .overlay(alignment: .top) {
                if let achievement = app.pendingUnlocks.first, !game.session.isWon {
                    UnlockBanner(achievement: achievement)
                        .id(achievement)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: achievement) {
                            try? await Task.sleep(for: .seconds(2.5))
                            withAnimation(.quiet) { app.dismissUnlock(achievement) }
                        }
                }
            }
            .animation(.quiet, value: app.pendingUnlocks)
            .onChange(of: game.session.isWon) { _, won in
                // The win sheet lists them instead.
                if won { app.pendingUnlocks.forEach(app.dismissUnlock) }
            }
        }
    }
}

/// "Achievement unlocked" toast during play.
private struct UnlockBanner: View {
    let achievement: Achievement
    @Environment(\.quietTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.systemImage)
                .foregroundStyle(theme.onPrimary)
                .frame(width: 36, height: 36)
                .background(theme.primary, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement unlocked")
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background { SurfaceShape(shape: Capsule()) }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .onAppear {
            AccessibilityNotification.Announcement(String(localized: "Achievement unlocked")).post()
        }
    }
}

/// Leaderboards, Collection and Settings, in a capsule at the top right.
private struct HomeMenu: View {
    @Environment(\.quietTheme) private var theme

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
                .foregroundStyle(theme.primary)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(id)
    }
}

/// Today's challenge, its difficulty and the streak.
private struct DailyCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.quietTheme) private var theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(theme.primary)
                    .frame(width: 44, height: 44)
                    .background(theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Challenge")
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    Text("\(Text(Deals.dailyDifficulty(forDayKey: app.todayKey).title)) · \(status)")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
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
                    .foregroundStyle(theme.accent)
                    .accessibilityLabel(Text("\(app.currentStreak)-day streak"))
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.muted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var status: Text {
        let today = app.todayKey
        if app.isDailyInProgress(today) { return Text("In progress") }
        guard let record = app.persistence.dailies[today] else { return Text("Not played yet") }
        return Text("Won · \(Text(record.score, format: .number))")
    }
}

/// Wins, best daily streak and the share of games won.
private struct StatsRow: View {
    @Environment(AppModel.self) private var app
    @Environment(\.quietTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your stats")
                .font(.subheadline.bold())
                .foregroundStyle(theme.muted)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                StatTile(value: Text(app.progress.gamesWon, format: .number), label: "Wins")
                StatTile(value: Text(app.longestStreak, format: .number), label: "Top streak")
                StatTile(value: Text(app.progress.winRate, format: .percent.precision(.fractionLength(0))), label: "Won")
            }
        }
    }
}

private struct StatTile: View {
    let value: Text
    let label: LocalizedStringKey

    @Environment(\.quietTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            value
                .font(.stat)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.footnote)
                .foregroundStyle(theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
        .accessibilityElement(children: .combine)
    }
}

extension Difficulty {
    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .expert: "Expert"
        }
    }
}
