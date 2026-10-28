import QuietCore
import QuietNumbersCore
import QuietUI
import SwiftUI

struct GameView: View {
    let model: GameModel
    let kind: GameKind
    /// Classic only.
    let onNewGame: () -> Void
    /// After every change to the session, to save it.
    let onSessionChange: () -> Void
    /// Best classic score so far; `nil` for daily challenges.
    let bestScore: Int?
    /// Achievements this game unlocked, for the summary.
    let unlocked: [Achievement]

    /// Best score when this game started, to spot a new record.
    @State private var startingBest: Int?
    /// Fireworks for a completed challenge, then the summary over the board.
    @State private var celebrates = false
    @State private var showsSummary = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appearance) private var appearance
    @Environment(\.quietTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            GameTopBar(
                model: model,
                subtitle: subtitle
            )
            DigitStrip(board: model.board)
                .padding(.top, 14)
            GeometryReader { geometry in
                BoardView(
                    model: model,
                    cell: Layout.boardCell(width: geometry.size.width, sizeClass: sizeClass, largerNumbers: largeBoardNumbers),
                    onTap: { cell in animate { model.tap(cell) } },
                    onDragStart: { cell in animate { model.beginDrag(at: cell) } }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 12)
            GameActionBar(
                model: model,
                onUndo: { animate { model.undo() } },
                onAddNumbers: { animate { model.addNumbers() } },
                onHint: { animate { model.showHint() } }
            )
        }
        .frame(maxWidth: Layout.boardWidth(sizeClass) + 48)
        .frame(maxWidth: .infinity)
        .screen {
            if kind == .classic {
                Menu {
                    Button("New Game", systemImage: "arrow.counterclockwise") { animate(onNewGame) }
                        .keyboardShortcut("n")
                } label: {
                    RoundIconLabel(systemImage: "ellipsis", tint: theme.primary)
                }
                .accessibilityLabel(Text("Menu"))
            }
        }
        .overlay {
            if let stage = model.stageBanner {
                StageBanner(stage: stage)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .task {
                        try? await Task.sleep(for: .seconds(1.4))
                        animate { model.stageBanner = nil }
                    }
            }
        }
        .overlay { summary }
        .onChange(of: model.session.isOver, initial: true) { _, isOver in
            guard isOver else { return }
            Task {
                // The last match plays out first; a completed challenge gets fireworks, and the
                // summary comes up under them.
                try? await Task.sleep(for: .seconds(0.5))
                if model.session.isCompleted, !reduceMotion {
                    celebrates = true
                    try? await Task.sleep(for: .seconds(1.4))
                }
                withAnimation(.quiet) { showsSummary = true }
            }
        }
        .task(id: scenePhase) {
            // The clock: one tick a second while the game is on screen and the app active.
            guard scenePhase == .active else { return saveTime() }
            while !Task.isCancelled, !model.session.isOver {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { model.tick() }
            }
        }
        .onChange(of: reduceMotion, initial: true) { model.reduceMotion = reduceMotion }
        .onChange(of: model.session) { onSessionChange() }
        .onAppear { if startingBest == nil { startingBest = bestScore } }
        .onDisappear(perform: saveTime)
    }

    /// Leaving the game or the app: the seconds since the last move get saved too.
    private func saveTime() {
        if model.commitTime() { onSessionChange() }
    }

    /// Fireworks in the theme's colors (as in Quiet Solitaire), over the summary sheet.
    private var summary: some View {
        ZStack(alignment: .bottom) {
            if showsSummary {
                Color.black.opacity(0.18).ignoresSafeArea()
                    .transition(.opacity)
                GameSummarySheet(
                    session: model.session,
                    kind: kind,
                    isNewBest: (startingBest ?? 0) > 0 && model.session.score > (startingBest ?? 0),
                    unlocked: unlocked,
                    onNewGame: { animate(onNewGame) },
                    onHome: { dismiss() }
                )
                .transition(.move(edge: .bottom))
            }
            if celebrates {
                Fireworks(colors: [theme.primary, theme.accent, theme.suitRed, Color(red: 0.89, green: 0.70, blue: 0.25), theme.ink.opacity(0.6)],
                          seed: fireworksSeed)
                    .ignoresSafeArea()
            }
        }
    }

    private var fireworksSeed: UInt64 {
        switch kind {
        case .classic: 7
        case .daily(let dayKey), .practice(let dayKey): FNV1a.hash(dayKey)
        }
    }

    private var largeBoardNumbers: Bool {
        appearance.largerNumbers || dynamicTypeSize.isAccessibilitySize
    }

    private var subtitle: Text {
        switch kind {
        case .classic:
            Text("Stage \(model.session.stage)") + Text(verbatim: " · ")
                + Text("Best \(Text(max(startingBest ?? bestScore ?? 0, model.displayedScore), format: .number))")
        case .daily: Text("Stage \(model.session.stage)") + goal
        case .practice(let dayKey): Text("Practice · \(DayKeyFormat.string(dayKey))") + goal
        }
    }

    /// " · Goal 500", or " · Goal reached" once it is. Empty for dailies saved before goals.
    private var goal: Text {
        guard let goal = model.session.goal else { return Text(verbatim: "") }
        let label = model.session.isCompleted
            ? Text("Goal reached")
            : Text("Goal \(Text(goal, format: .number))")
        return Text(verbatim: " · ") + label
    }

    /// Reduce Motion keeps a short fade but drops movement and scaling.
    private func animate(_ body: () -> Void) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .quiet, body)
    }
}

private struct StageBanner: View {
    let stage: Int

    @Environment(\.quietTheme) private var theme

    var body: some View {
        Text("Stage \(stage)")
            .font(.system(.title, design: .rounded, weight: .heavy))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background { SurfaceShape(shape: Capsule()) }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// End of a game: the score, how it went and what it unlocked. Same sheet as Quiet
/// Solitaire's; a completed challenge also gets fireworks over it.
private struct GameSummarySheet: View {
    let session: GameSession
    let kind: GameKind
    let isNewBest: Bool
    let unlocked: [Achievement]
    let onNewGame: () -> Void
    let onHome: () -> Void

    @Environment(\.quietTheme) private var theme

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(session.isCompleted ? "Challenge complete" : "No moves left")
                    .font(.headline)
                    .foregroundStyle(theme.muted)
                Text(session.score, format: .number)
                    .font(.score(size: 56))
                    .foregroundStyle(theme.ink)
                if isNewBest {
                    tag(Text("New best score!"))
                } else if case .practice = kind {
                    tag(Text("Not scored"))
                }
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 0) {
                if let goal = session.goal {
                    row("Goal", Text(goal, format: .number))
                }
                row("Time", Text(GameClock.string(session.elapsedSeconds)))
                if session.goal != nil || kind == .classic {
                    row("Stage", Text(session.stage, format: .number))
                }
                row("Pairs", Text(session.stats.pairs, format: .number))
                row("Rows cleared", Text(session.stats.rowsCleared, format: .number))
                row("+ used", Text(session.stats.plusUsed, format: .number))
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
                            achievement.badge
                                .resizable()
                                .frame(width: 36, height: 36)
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
                if kind == .classic {
                    Button("New Game", action: onNewGame)
                        .buttonStyle(CapsuleButtonStyle())
                    Button("Home", action: onHome)
                        .buttonStyle(CapsuleButtonStyle(isProminent: false))
                } else {
                    Button("Done", action: onHome)
                        .buttonStyle(CapsuleButtonStyle())
                }
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

    private func tag(_ text: Text) -> some View {
        text
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(theme.accent.opacity(0.14), in: Capsule())
            .padding(.top, 4)
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
        .accessibilityElement(children: .combine)
    }
}

/// 1 to 9 above the board; a digit with none left on it fades and is struck through.
private struct DigitStrip: View {
    let board: Board

    @Environment(\.quietTheme) private var theme

    var body: some View {
        let left = Set(board.activeValues)
        HStack(spacing: 0) {
            ForEach(1...9, id: \.self) { digit in
                let isGone = !left.contains(digit)
                Text(digit, format: .number)
                    .font(.system(.subheadline, design: .rounded, weight: .bold).monospacedDigit())
                    .strikethrough(isGone, color: theme.muted)
                    .foregroundStyle(isGone ? theme.ghost : theme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24)
        .animation(.quiet, value: left)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Numbers left: \((1...9).filter(left.contains).map(String.init).formatted(.list(type: .and)))"))
    }
}
