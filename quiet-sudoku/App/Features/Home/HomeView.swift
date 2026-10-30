import GameKit
import QuietCore
import QuietSudokuCore
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
    @State private var choosesLevel = false

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
                        Text(verbatim: "Quiet Sudoku")
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
                        if let level = app.classicInProgress {
                            Button {
                                Task {
                                    await app.continueClassic()
                                    path.append(.game)
                                }
                            } label: {
                                Text("Continue · \(Text(level.title))")
                            }
                            .buttonStyle(CapsuleButtonStyle())
                            .accessibilityIdentifier("continue")
                        }
                        Button {
                            if app.needsTutorial {
                                path.append(.tutorial)
                            } else {
                                choosesLevel = true
                            }
                        } label: {
                            if app.isPreparing {
                                ProgressView()
                            } else {
                                Text("New Game")
                            }
                        }
                        .buttonStyle(CapsuleButtonStyle(isProminent: !app.hasClassicInProgress))
                        .disabled(app.isPreparing)
                        .accessibilityIdentifier("newGame")
                        .confirmationDialog("Choose a level", isPresented: $choosesLevel, titleVisibility: .visible) {
                            ForEach(Difficulty.allCases, id: \.self) { level in
                                Button { newGame(level) } label: { Text(level.title) }
                                    .accessibilityIdentifier("level-\(level)")
                            }
                        } message: {
                            Text("Easy needs only the basics. Each level up needs one more kind of reasoning.")
                        }
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
                    ActiveGameView(onNewGame: newGame)
                case .daily:
                    DailyChallengeView { dayKey in
                        Task {
                            await app.playDaily(dayKey)
                            path.append(.game)
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
                            await app.newClassic(.easy)
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

    /// A fresh classic game, opened once it's ready (or replacing the one on screen).
    private func newGame(_ level: Difficulty) {
        Task {
            await app.newClassic(level)
            if path.last != .game { path.append(.game) }
        }
    }

    /// Game Center's access point, only on Home and only when signed in.
    private func updateAccessPoint() {
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.isActive = app.gameCenter.isAuthenticated && path.isEmpty
    }

    #if DEBUG
    /// UI tests: `-startGame` opens a game right away; `-seedKey <text>` makes its puzzle
    /// deterministic; `-level <0-3>` picks the level; `-nearlyWon` leaves one empty cell;
    /// `-hint` applies a hint.
    private func startDebugGameIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        // `-open <daily|leaderboards|collection|settings|tutorial>`: straight there (design captures).
        if let name = value(after: "-open"), path.isEmpty {
            let routes: [String: Route] = ["daily": .daily, "leaderboards": .leaderboards, "collection": .collection,
                                           "settings": .settings, "tutorial": .tutorial]
            if let route = routes[name] { return path = [route] }
        }
        guard arguments.contains("-startGame"), path.isEmpty else { return }
        let level = value(after: "-level").flatMap(Int.init).flatMap(Difficulty.init) ?? .easy
        let puzzle = Generator.puzzle(key: value(after: "-seedKey") ?? "debug-\(UInt64.random(in: .min ... .max))", difficulty: level)
        var session = GameSession(puzzle: puzzle, values: puzzle.givens.cells, elapsedSeconds: DemoData.clock)
        if arguments.contains("-nearlyWon") {
            let empty = (0..<81).filter { puzzle.givens[$0] == 0 }
            for cell in empty.dropLast() { session.place(puzzle.solution[cell], at: cell) }
        }
        let model = GameModel(session: session)
        app.start(model, as: .classic)
        // `-hint`: opens with a hint applied (design captures).
        if arguments.contains("-hint") { model.requestHint() }
        path = [.game]
    }
    #endif
}

/// The game `AppModel` has on screen.
private struct ActiveGameView: View {
    @Environment(AppModel.self) private var app
    let onNewGame: (Difficulty) -> Void

    var body: some View {
        if let game = app.activeGame, let kind = app.activeKind {
            GameView(
                model: game,
                kind: kind,
                bestScore: kind == .classic ? app.bestAtStart : nil,
                unlocked: app.unlockedThisGame,
                onNewGame: onNewGame,
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
                    Text("\(Text(DailyChallenge.difficulty(forDayKey: app.todayKey).title)) · \(status)")
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
