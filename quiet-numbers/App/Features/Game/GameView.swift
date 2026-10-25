import QuietNumbersCore
import SwiftUI

struct GameView: View {
    let model: GameModel
    let onNewGame: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    private static let maxBoardWidth: CGFloat = 540

    var body: some View {
        VStack(spacing: 0) {
            GameTopBar(
                model: model,
                onAddNumbers: { animate { model.addNumbers() } },
                onHint: { animate { model.showHint() } }
            )
            GeometryReader { geometry in
                let width = min(geometry.size.width - 16, Self.maxBoardWidth)
                let size = (width / CGFloat(Board.columns)).rounded(.down)
                BoardView(model: model, size: size) { cell in
                    animate { model.tap(cell) }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: Self.maxBoardWidth + 32)
        .frame(maxWidth: .infinity)
        .background(.background)
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
                    score: model.session.score,
                    onNewGame: { animate(onNewGame) },
                    onHome: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Game", systemImage: "arrow.counterclockwise") { animate(onNewGame) }
                        .keyboardShortcut("n")
                } label: {
                    Label("Menu", systemImage: "ellipsis.circle")
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
    let score: Int
    let onNewGame: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("No moves left")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            VStack(spacing: 4) {
                Text("Final score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(score, format: .number)
                    .font(.score)
            }
            VStack(spacing: 10) {
                Button(action: onNewGame) {
                    Text("New Game").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(action: onHome) {
                    Text("Home").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
        }
        .padding(28)
        .frame(maxWidth: 320)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.15))
    }
}
