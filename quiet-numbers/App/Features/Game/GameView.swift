import QuietNumbersCore
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

    /// Best score when this game started, to spot a new record.
    @State private var startingBest: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appearance) private var appearance
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            GameTopBar(
                model: model,
                subtitle: subtitle
            )
            GeometryReader { geometry in
                BoardView(
                    model: model,
                    cell: Layout.boardCell(width: geometry.size.width, sizeClass: sizeClass, largerNumbers: largeBoardNumbers),
                    onTap: { cell in animate { model.tap(cell) } },
                    onDragStart: { cell in animate { model.beginDrag(at: cell) } }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 20)
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
                    RoundIconLabel(systemImage: "ellipsis", tint: appearance.theme.primary)
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
        .overlay {
            if model.session.isOver {
                GameOverView(
                    session: model.session,
                    kind: kind,
                    isNewBest: (startingBest ?? 0) > 0 && model.session.score > (startingBest ?? 0),
                    onNewGame: { animate(onNewGame) },
                    onHome: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .onChange(of: reduceMotion, initial: true) { model.reduceMotion = reduceMotion }
        .onChange(of: model.session) { onSessionChange() }
        .onAppear { if startingBest == nil { startingBest = bestScore } }
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

    @Environment(\.appearance) private var appearance

    var body: some View {
        Text("Stage \(stage)")
            .font(.system(.title, design: .rounded, weight: .heavy))
            .foregroundStyle(appearance.theme.ink)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background { SurfaceShape(shape: Capsule()) }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .accessibilityAddTraits(.isStaticText)
    }
}

private struct GameOverView: View {
    let session: GameSession
    let kind: GameKind
    let isNewBest: Bool
    let onNewGame: () -> Void
    let onHome: () -> Void

    @Environment(\.appearance) private var appearance

    var body: some View {
        VStack(spacing: 20) {
            Text(session.isCompleted ? "Challenge complete" : "No moves left")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(appearance.theme.ink)
            VStack(spacing: 4) {
                Text("Final score")
                    .font(.subheadline)
                    .foregroundStyle(appearance.theme.muted)
                Text(session.score, format: .number)
                    .font(.score)
                    .foregroundStyle(appearance.theme.ink)
                if isNewBest {
                    Toast(text: Text("New best score!"))
                        .padding(.top, 4)
                }
                if case .practice = kind {
                    Text("Not scored")
                        .font(.subheadline)
                        .foregroundStyle(appearance.theme.muted)
                }
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
        .padding(24)
        .frame(maxWidth: 340)
        .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 28, style: .continuous)) }
        .shadow(color: .black.opacity(0.15), radius: 24, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.2))
    }
}
