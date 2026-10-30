import QuietSudokuCore
import QuietUI
import SwiftUI

/// A game: score on top, the board, Undo / Erase / Notes / Hint, and the keypad.
struct GameView: View {
    let model: GameModel
    let kind: GameKind
    /// Classic best before this game, for "Best" and "New record!".
    let bestScore: Int?
    let unlocked: [Achievement]
    let onNewGame: (Difficulty) -> Void
    let onRestart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.quietTheme) private var theme
    @Environment(\.appearance) private var appearance
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsWin = false
    @State private var celebrates = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geometry in
                let size = min(geometry.size.width - 16, Layout.boardWidth(sizeClass), geometry.size.height)
                VStack(spacing: 0) {
                    BoardView(model: model, size: size)
                    HintCard(model: model)
                        .frame(maxWidth: size)
                        .padding(.top, 12)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 12)
            bottomBar
            Keypad(model: model)
                .frame(maxWidth: Layout.boardWidth(sizeClass))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .background(theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) { noteToast }
        .onAppear { model.showsMistakes = appearance.showsMistakes }
        .onChange(of: appearance.showsMistakes) { _, shows in model.showsMistakes = shows }
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
                // Wave: the board lights up first. Then fireworks, and the sheet over them.
                if appearance.victory == .wave, !reduceMotion { try? await Task.sleep(for: .seconds(1.0)) }
                celebrates = !reduceMotion
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1.4))
                withAnimation(.quiet) { showsWin = true }
            }
        }
        .background { KeyboardShortcuts(model: model) }
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
            Text(model.shownScore, format: .number)
                .font(.score(size: 40))
                .foregroundStyle(theme.ink)
                .contentTransition(.numericText(value: Double(model.shownScore)))
                .animation(.quiet, value: model.shownScore)
                .accessibilityLabel(Text("Score \(model.shownScore)"))
                .accessibilityIdentifier("score")
            Spacer()
            Menu {
                if kind == .classic {
                    Menu {
                        ForEach(Difficulty.allCases, id: \.self) { level in
                            Button { onNewGame(level) } label: { Text(level.title) }
                        }
                    } label: {
                        Label("New Game", systemImage: "plus")
                    }
                }
                Button { onRestart() } label: { Label("Restart This Sudoku", systemImage: "arrow.counterclockwise") }
            } label: {
                RoundIconLabel(systemImage: "ellipsis")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("More"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    /// Time, mistakes and the level (or the mode), in a row under the score.
    private var stats: some View {
        HStack(alignment: .top) {
            Stat(title: "Time", value: Text(GameClock.string(model.session.elapsedSeconds)))
                .accessibilityIdentifier("time")
            Spacer()
            Stat(title: "Mistakes", value: appearance.showsMistakes ? Text(model.session.mistakes, format: .number) : Text(verbatim: "–"))
                .accessibilityIdentifier("mistakes")
            Spacer()
            switch kind {
            case .classic: Stat(title: "Level", value: Text(model.session.difficulty.title))
            case .daily: Stat(title: "Daily", value: Text(model.session.difficulty.title))
            case .practice: Stat(title: "Practice", value: Text(model.session.difficulty.title))
            }
        }
        .padding(.horizontal, 24)
    }

    private var bottomBar: some View {
        HStack(alignment: .top) {
            BarButton(title: "Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                .disabled(!model.session.canUndo || model.isTutorial)
                .accessibilityIdentifier("undo")
            Spacer()
            BarButton(title: "Erase", systemImage: "eraser") { model.erase() }
                .disabled(model.session.isWon || model.isTutorial)
                .accessibilityIdentifier("erase")
            Spacer()
            BarButton(title: "Notes", systemImage: "pencil", isOn: model.isNoting) { model.isNoting.toggle() }
                .disabled(model.session.isWon)
                .accessibilityValue(model.isNoting ? Text("On") : Text("Off"))
                .accessibilityIdentifier("notes")
            Spacer()
            BarButton(title: "Hint", systemImage: "lightbulb") { model.requestHint() }
                .disabled(model.session.isWon)
                .accessibilityIdentifier("hint")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
        .padding(.top, 4)
        .frame(maxWidth: Layout.buttons(sizeClass) + 60)
    }

    // MARK: Notices

    @ViewBuilder
    private var noteToast: some View {
        if let note = model.note {
            Toast(text: Text(note))
                .padding(.bottom, 170)
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
                Fireworks(colors: [theme.primary, theme.accent, Color(red: 0.89, green: 0.70, blue: 0.25), theme.ink.opacity(0.6)],
                          seed: model.session.puzzle.seed)
                    .ignoresSafeArea()
            }
        }
    }

    private var winSheet: some View {
        WinSheet(
            session: model.session,
            isRecord: kind == .classic && model.session.score > (bestScore ?? 0),
            unlocked: unlocked,
            showsNewGame: kind == .classic,
            onNewGame: { onNewGame(model.session.difficulty) },
            onHome: { dismiss() }
        )
        .transition(.move(edge: .bottom))
    }
}

/// Keyboard (iPad, Mac): digits, arrows, N notes, ⌫ erase, ⌘Z undo, H hint.
private struct KeyboardShortcuts: View {
    let model: GameModel

    var body: some View {
        Group {
            ForEach(1...9, id: \.self) { digit in
                Button(String(digit)) { model.input(digit) }
                    .keyboardShortcut(KeyEquivalent(Character(String(digit))), modifiers: [])
            }
            Button("Undo") { model.undo() }.keyboardShortcut("z", modifiers: .command)
            Button("Hint") { model.requestHint() }.keyboardShortcut("h", modifiers: [])
            Button("Notes") { model.isNoting.toggle() }.keyboardShortcut("n", modifiers: [])
            Button("Erase") { model.erase() }.keyboardShortcut(.delete, modifiers: [])
            arrow(.upArrow, rows: -1, columns: 0)
            arrow(.downArrow, rows: 1, columns: 0)
            arrow(.leftArrow, rows: 0, columns: -1)
            arrow(.rightArrow, rows: 0, columns: 1)
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func arrow(_ key: KeyEquivalent, rows: Int, columns: Int) -> some View {
        Button("") { model.moveSelection(rows: rows, columns: columns) }
            .keyboardShortcut(key, modifiers: [])
    }
}

/// The hint's explanation, under the board until the next action.
private struct HintCard: View {
    let model: GameModel

    @Environment(\.quietTheme) private var theme

    var body: some View {
        if let hint = model.hint {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(hint.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.ink)
                    Text(hint.body)
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button { model.dismissHint() } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.muted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }
            .padding(14)
            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("hintCard")
        }
    }
}

/// 1–9, with how many of each are left. A finished digit fades.
private struct Keypad: View {
    let model: GameModel

    @Environment(\.quietTheme) private var theme
    @Environment(\.appearance) private var appearance

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { digit in
                let left = 9 - model.session.count(of: digit)
                Button { model.input(digit) } label: {
                    VStack(spacing: 0) {
                        Text(verbatim: "\(digit)")
                            .font(appearance.digits.font(size: model.isNoting ? 22 : 30, weight: .medium))
                            .foregroundStyle(model.isNoting ? theme.muted : theme.primary)
                        Text(verbatim: "\(left)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(theme.muted)
                            .opacity(left > 0 ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(left == 0 ? 0.35 : 1)
                .disabled(left == 0 || model.session.isWon)
                .accessibilityLabel(model.isNoting ? Text("Note \(digit)") : Text("\(digit)"))
                .accessibilityValue(Text("\(left) left"))
                .accessibilityIdentifier("digit-\(digit)")
            }
        }
    }
}

extension GameSession.Hint {
    var title: LocalizedStringResource {
        switch self {
        case .mistake: "Mistake"
        case .step(let step, _): step.technique.title
        }
    }

    var body: String {
        switch self {
        case .mistake:
            return String(localized: "This digit doesn't go here. It's been cleared.")
        case .step(let step, let hardest):
            guard let placement = step.placement else { return "" }
            let digit = placement.digit
            var text = switch step.technique {
            case .fullHouse:
                String(localized: "It's the last empty cell of \(unitName(step.units[0])): the \(digit) goes here.")
            case .hiddenSingle:
                String(localized: "In \(unitName(step.units[0])), the \(digit) fits only here.")
            default:
                String(localized: "Only the \(digit) fits here: its row, column and box hold the other eight.")
            }
            if hardest.difficulty > .easy {
                text += " " + String(localized: "To see it, first rule out candidates with \(String(localized: hardest.title)). See Settings › Techniques.")
            }
            return text
        }
    }
}

/// Round 56 pt button with a caption, for the bottom bar.
private struct BarButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isOn = false
    let action: () -> Void

    @Environment(\.quietTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn ? theme.onPrimary : theme.ink)
                    .frame(width: 52, height: 52)
                    .background { SurfaceShape(shape: Circle(), fill: isOn ? theme.primary : nil) }
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
                Text("Solved!")
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
                row("Level", Text(session.difficulty.title))
                row("Digits", Text(session.playPoints, format: .number))
                row("Solve bonus", Text(session.winBonus, format: .number.sign(strategy: .always())))
                if let tenths = session.timeMultiplierTenths {
                    row(LocalizedStringKey("Time ×\(Double(tenths) / 10, format: .number.precision(.fractionLength(1)))"),
                        Text(session.timeBonus, format: .number.sign(strategy: .always())))
                }
                row(LocalizedStringKey("Mistakes \(session.mistakes) × −\(session.scoring.mistake)"),
                    Text(-session.mistakeCost, format: .number.sign(strategy: .always(includingZero: false))))
                row(LocalizedStringKey("Hints \(session.hintsUsed) × −\(session.scoring.hint)"),
                    Text(-session.hintCost, format: .number.sign(strategy: .always(includingZero: false))), last: true)
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
