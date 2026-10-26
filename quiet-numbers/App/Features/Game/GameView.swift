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

    private static let maxBoardWidth: CGFloat = 540

    var body: some View {
        VStack(spacing: 0) {
            GameTopBar(
                model: model,
                subtitle: subtitle
            )
            GeometryReader { geometry in
                let width = min(geometry.size.width - 16, Self.maxBoardWidth)
                let size = (width / CGFloat(Board.columns)).rounded(.down)
                BoardView(model: model, size: size) { cell in
                    animate { model.tap(cell) }
                }
                .frame(maxWidth: .infinity)
            }
            GameActionBar(
                model: model,
                onUndo: { animate { model.undo() } },
                onAddNumbers: { animate { model.addNumbers() } },
                onHint: { animate { model.showHint() } }
            )
        }
        .frame(maxWidth: Self.maxBoardWidth + 32)
        .frame(maxWidth: .infinity)
        .background(appearance.theme.background)
        .overlayPreferenceValue(ScoreAnchorKey.self) { anchor in
            GameFeedbackOverlay(model: model, scoreAnchor: anchor)
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
        .toolbar {
            if kind == .classic {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Game", systemImage: "arrow.counterclockwise") { animate(onNewGame) }
                            .keyboardShortcut("n")
                    } label: {
                        Label("Menu", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var subtitle: Text {
        switch kind {
        case .classic:
            Text("Stage \(model.session.stage)") + Text(verbatim: " · ")
                + Text("Best \(Text(max(startingBest ?? bestScore ?? 0, model.displayedScore), format: .number))")
        case .daily: Text("Daily Challenge")
        case .practice(let dayKey): Text("Practice · \(DayKeyFormat.string(dayKey))")
        }
    }

    /// Reduce Motion keeps a short fade but drops movement and scaling.
    private func animate(_ body: () -> Void) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .quiet, body)
    }
}

private struct StageBanner: View {
    let stage: Int

    var body: some View {
        Text("Stage \(stage)")
            .font(.system(.title, design: .rounded, weight: .semibold))
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: Capsule())
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
                .font(.system(.title2, design: .rounded, weight: .semibold))
            VStack(spacing: 4) {
                Text("Final score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(session.score, format: .number)
                    .font(.score)
                if isNewBest {
                    Text("New best score!")
                        .font(.headline)
                        .foregroundStyle(Color.highlight)
                }
                if case .practice = kind {
                    Text("Not scored")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 10) {
                if kind == .classic {
                    Button(action: onNewGame) {
                        Text("New Game").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(action: onHome) {
                        Text("Home").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: onHome) {
                        Text("Done").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
        }
        .padding(28)
        .frame(maxWidth: 320)
        .background(appearance.theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.15))
    }
}
