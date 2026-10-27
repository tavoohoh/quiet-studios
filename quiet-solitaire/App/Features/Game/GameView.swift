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

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geometry in
                BoardView(model: model, layout: BoardLayout(
                    size: geometry.size, maxWidth: Layout.boardWidth(sizeClass), leftHanded: appearance.leftHanded
                ))
            }
            .padding(.top, 18)
            bottomBar
        }
        .background(theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) { notices }
        .overlay { if showsWin { winSheet } }
        .onChange(of: model.session.isWon, initial: true) { _, won in
            guard won else { return showsWin = false }
            Task {
                try? await Task.sleep(for: .seconds(appearance.victory == .cascade ? 1.6 : 0.6))
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
        HStack(alignment: .top) {
            Button { dismiss() } label: { RoundIconLabel(systemImage: "chevron.backward") }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("back")
            Spacer()
            VStack(spacing: 2) {
                Text(model.session.score, format: .number)
                    .font(.score(size: 40))
                    .foregroundStyle(theme.ink)
                    .contentTransition(.numericText(value: Double(model.session.score)))
                    .animation(.quiet, value: model.session.score)
                    .accessibilityLabel(Text("Score \(model.session.score)"))
                    .accessibilityIdentifier("score")
                subtitle
                    .font(.counter)
                    .foregroundStyle(theme.muted)
            }
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

    private var subtitle: Text {
        let moves = Text("\(model.session.moves) moves")
        switch kind {
        case .classic: return Text("\(moves) · Best \(Text(max(bestScore ?? 0, 0), format: .number))")
        case .daily: return Text("\(moves) · Daily challenge")
        case .practice: return Text("\(moves) · Practice")
        }
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

    @ViewBuilder
    private var notices: some View {
        if model.isStuck, !model.session.isWon {
            VStack(spacing: 10) {
                Text("No way to win from here")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                HStack(spacing: 10) {
                    Button("Undo") { model.undo() }
                        .buttonStyle(CapsuleButtonStyle(isProminent: false))
                    if kind == .classic {
                        Button("New Game") { onNewGame() }
                            .buttonStyle(CapsuleButtonStyle())
                    }
                }
            }
            .padding(18)
            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 96)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let note = model.hintNote {
            Toast(text: Text(note))
                .padding(.bottom, 100)
                .transition(.opacity)
        }
    }

    private var winSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.18).ignoresSafeArea()
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
                row("Moves", Text(session.moves, format: .number))
                row("Game points", Text(session.playPoints, format: .number))
                row("Few-moves bonus", Text(session.winBonus, format: .number.sign(strategy: .always())))
                row("Hints", Text(session.hintsUsed, format: .number), last: true)
            }
            .padding(.horizontal, 16)
            .background(theme.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            ForEach(unlocked, id: \.self) { achievement in
                HStack(spacing: 12) {
                    Image(systemName: achievement.systemImage)
                        .font(.title3)
                        .foregroundStyle(theme.onPrimary)
                        .frame(width: 44, height: 44)
                        .background(theme.primary, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achievement unlocked")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.muted)
                        Text(achievement.title)
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                    }
                    Spacer()
                }
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
