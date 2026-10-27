import QuietSolitaireCore
import QuietUI
import SwiftUI

/// A game: score on top, the table, Undo / Auto-complete / Hint at the thumb.
struct GameView: View {
    let model: GameModel
    let kind: GameKind
    /// Classic best before this game, for "Best" and "New record!".
    let bestScore: Int?
    let unlocked: [Achievement]
    let onNewGame: () -> Void
    let onRestart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.quietTheme) private var theme
    @Environment(\.appearance) private var appearance
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showsWin = false
    @State private var celebrates = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geometry in
                BoardView(model: model, layout: BoardLayout(
                    size: geometry.size, maxWidth: Layout.boardWidth(sizeClass), leftHanded: appearance.leftHanded
                ))
            }
            .padding(.top, 14)
            bottomBar
        }
        .background(theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) { hintNote }
        .overlay(alignment: .bottom) { milestoneToast }
        .overlay { if model.isStuck, !model.session.isWon { stuckNotice } }
        .onAppear { SwipeBack.isEnabled = false }
        .onDisappear { SwipeBack.isEnabled = true }
        .animation(.quiet, value: model.isStuck)
        .task(id: scenePhase) {
            // The clock: one tick a second while the game is on screen and the app active.
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { model.tick() }
            }
        }
        .overlay { victory }
        .onChange(of: model.session.isWon, initial: true) { _, won in
            guard won else {
                celebrates = false
                return showsWin = false
            }
            Task {
                // Cascade: the cards tumble first. Then fireworks, and the sheet over them.
                if appearance.victory == .cascade { try? await Task.sleep(for: .seconds(1.2)) }
                celebrates = true
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.quiet) { showsWin = true }
            }
        }
        .background {
            // Keyboard (iPad, Mac): ⌘Z undo, H hint, space draws.
            Group {
                Button("Undo") { model.undo() }.keyboardShortcut("z", modifiers: .command)
                Button("Hint") { Task { await model.requestHint() } }.keyboardShortcut("h", modifiers: [])
                Button("Draw") { model.drawFromStock() }.keyboardShortcut(.space, modifiers: [])
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    // MARK: Bars

    private var topBar: some View {
        VStack(spacing: 10) {
            scoreRow
            stats
        }
    }

    private var scoreRow: some View {
        HStack(alignment: .center) {
            Button { dismiss() } label: { RoundIconLabel(systemImage: "chevron.backward") }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("back")
            Spacer()
            Text(model.session.score, format: .number)
                .font(.score(size: 40))
                .foregroundStyle(theme.ink)
                .contentTransition(.numericText(value: Double(model.session.score)))
                .animation(.quiet, value: model.session.score)
                .accessibilityLabel(Text("Score \(model.session.score)"))
                .accessibilityIdentifier("score")
            Spacer()
            Menu {
                if kind == .classic {
                    Button { onNewGame() } label: { Label("New Game", systemImage: "plus") }
                }
                Button { onRestart() } label: { Label("Restart This Deal", systemImage: "arrow.counterclockwise") }
            } label: {
                RoundIconLabel(systemImage: "ellipsis")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("More"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    /// Time, moves and the record (or the mode), in a row under the score.
    private var stats: some View {
        HStack(alignment: .top) {
            Stat(title: "Time", value: Text(GameClock.string(model.session.elapsedSeconds)))
                .accessibilityIdentifier("time")
            Spacer()
            Stat(title: "Moves", value: Text(model.session.moves, format: .number))
            Spacer()
            switch kind {
            case .classic: Stat(title: "Best", value: Text(max(bestScore ?? 0, 0), format: .number))
            case .daily(let day): Stat(title: "Daily", value: Text(Deals.dailyDifficulty(forDayKey: day).title))
            case .practice: Stat(title: "Practice", value: Text(verbatim: "–"))
            }
        }
        .padding(.horizontal, 24)
    }

    private var bottomBar: some View {
        HStack(alignment: .top) {
            BarButton(title: "Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                .disabled(!model.session.canUndo)
                .accessibilityIdentifier("undo")
            Spacer()
            if model.canAutoComplete {
                Button("Auto-complete") { Task { await model.autoComplete() } }
                    .buttonStyle(CapsuleButtonStyle())
                    .fixedSize()
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityIdentifier("autoComplete")
            }
            Spacer()
            BarButton(title: "Hint", systemImage: "lightbulb") { Task { await model.requestHint() } }
                .disabled(model.isFindingHint || model.session.isWon)
                .accessibilityIdentifier("hint")
        }
        .animation(.quiet, value: model.canAutoComplete)
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .padding(.top, 4)
    }

    // MARK: Notices

    /// The game can't be won any more: the table is dimmed and blocked until the player
    /// chooses. Keeping on playing is a deliberate choice, not something to tap past.
    private var stuckNotice: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                Image(systemName: "xmark.octagon")
                    .font(.title2)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                Text("No way to win from here")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text("Undo to go back, or start a new game.")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button("Undo") { model.undo() }
                        .buttonStyle(CapsuleButtonStyle(isProminent: false))
                        .disabled(!model.session.canUndo)
                    if kind == .classic {
                        Button("New Game") { onNewGame() }
                            .buttonStyle(CapsuleButtonStyle())
                    }
                }
                Button("Keep playing") { model.keepPlaying() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primary)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("keepPlaying")
            }
            .padding(20)
            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
            .shadow(color: .black.opacity(0.18), radius: 20, y: 6)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private var hintNote: some View {
        if let note = model.hintNote {
            Toast(text: Text(note))
                .padding(.bottom, 100)
                .transition(.opacity)
        }
    }

    /// Fireworks in the theme's colors, and the win sheet under them.
    private var victory: some View {
        ZStack(alignment: .bottom) {
            if showsWin {
                Color.black.opacity(0.18).ignoresSafeArea()
                    .transition(.opacity)
            }
            if showsWin { winSheet }
            // Over everything, sheet included; it never takes touches.
            if celebrates {
                Fireworks(colors: [theme.primary, theme.accent, theme.suitRed, .hex("#E3B341"), theme.ink.opacity(0.6)],
                          seed: model.session.seed)
                    .ignoresSafeArea()
            }
        }
    }

    /// "Spades complete!", "All cards face up!": a short toast above the bottom bar.
    @ViewBuilder
    private var milestoneToast: some View {
        if let milestone = model.milestone {
            Toast(text: milestone.text)
                .padding(.bottom, 104)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private var winSheet: some View {
        ZStack(alignment: .bottom) {
            WinSheet(
                session: model.session,
                isRecord: kind == .classic && model.session.score > (bestScore ?? 0),
                unlocked: unlocked,
                showsNewGame: kind == .classic,
                onNewGame: onNewGame,
                onHome: { dismiss() }
            )
            .transition(.move(edge: .bottom))
        }
    }
}

/// Round 56 pt button with a caption, for the bottom bar.
private struct BarButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    @Environment(\.quietTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .frame(width: 56, height: 56)
                    .background { SurfaceShape(shape: Circle()) }
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.muted)
            }
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
    }
}

/// End of a won game: score, how it was made, what it unlocked.
struct WinSheet: View {
    let session: GameSession
    let isRecord: Bool
    let unlocked: [Achievement]
    let showsNewGame: Bool
    let onNewGame: () -> Void
    let onHome: () -> Void

    @Environment(\.quietTheme) private var theme

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("You won!")
                    .font(.headline)
                    .foregroundStyle(theme.muted)
                Text(session.score, format: .number)
                    .font(.score(size: 56))
                    .foregroundStyle(theme.ink)
                if isRecord {
                    Text("New record!")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(theme.accent.opacity(0.14), in: Capsule())
                        .padding(.top, 4)
                }
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                row("Time", Text(GameClock.string(session.elapsedSeconds)))
                row("Moves", Text(session.moves, format: .number))
                row("Game points", Text(session.playPoints, format: .number))
                row("Few-moves bonus", Text(session.winBonus, format: .number.sign(strategy: .always())))
                if let tenths = session.timeMultiplierTenths {
                    row(LocalizedStringKey("Time ×\(Double(tenths) / 10, format: .number.precision(.fractionLength(1)))"),
                        Text(session.timeBonus, format: .number.sign(strategy: .always())))
                }
                row("Hints", Text(session.hintsUsed, format: .number), last: true)
            }
            .padding(.horizontal, 16)
            .background(theme.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if !unlocked.isEmpty {
                // One card however many: badges in a row, names below.
                VStack(alignment: .leading, spacing: 8) {
                    Text(unlocked.count == 1 ? "Achievement unlocked" : "Achievements unlocked")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.muted)
                    HStack(spacing: -6) {
                        ForEach(unlocked, id: \.self) { achievement in
                            Image(systemName: achievement.systemImage)
                                .font(.subheadline)
                                .foregroundStyle(theme.onPrimary)
                                .frame(width: 36, height: 36)
                                .background(theme.primary, in: Circle())
                                .overlay { Circle().stroke(theme.surface, lineWidth: 2) }
                        }
                    }
                    .accessibilityHidden(true)
                    Text(unlocked.map { String(localized: $0.title) }.formatted(.list(type: .and)))
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(theme.surface2, lineWidth: 1.5) }
                .accessibilityElement(children: .combine)
            }

            VStack(spacing: 10) {
                if showsNewGame {
                    Button("New Game", action: onNewGame)
                        .buttonStyle(CapsuleButtonStyle())
                        .accessibilityIdentifier("winNewGame")
                }
                Button("Home", action: onHome)
                    .buttonStyle(CapsuleButtonStyle(isProminent: !showsNewGame))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: 520)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                .fill(theme.surface)
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.08), radius: 30, y: -8)
        }
    }

    private func row(_ title: LocalizedStringKey, _ value: Text, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).foregroundStyle(theme.muted)
                Spacer()
                value.fontWeight(.heavy).monospacedDigit().foregroundStyle(theme.ink)
            }
            .font(.subheadline)
            .frame(height: 40)
            if !last { Rectangle().fill(theme.separator).frame(height: 1) }
        }
    }
}

/// A small label over a value, like the reference board's header.
private struct Stat: View {
    let title: LocalizedStringKey
    let value: Text

    @Environment(\.quietTheme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.muted)
            value
                .font(.system(.subheadline, design: .rounded, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.ink)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }
}

/// "05:16", or "1:05:16" past an hour.
enum GameClock {
    static func string(_ seconds: Int) -> String {
        let duration = Duration.seconds(seconds)
        return seconds >= 3600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    }
}

extension GameModel.Milestone {
    var text: Text {
        switch self {
        case .foundationComplete(let suit):
            let names: [LocalizedStringResource] = ["Spades complete!", "Hearts complete!", "Diamonds complete!", "Clubs complete!"]
            return Text(names[suit.rawValue])
        case .allRevealed:
            return Text("All cards face up!")
        }
    }
}
