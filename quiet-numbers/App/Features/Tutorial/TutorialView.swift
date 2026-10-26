import QuietNumbersCore
import SwiftUI

/// Interactive tutorial on the real board: each step rings the pair to play (like a hint),
/// explains why it's a pair, and only that move counts. Shown before the first game and
/// from Settings › How to play. Nothing here counts for progress.
struct TutorialView: View {
    /// First run: ends by starting a game. From Settings: ends by going back.
    let isFirstRun: Bool
    let onFinish: () -> Void

    @State private var model = GameModel(session: TutorialScript.session())
    @State private var stepIndex = 0
    @State private var isFinished = false
    @State private var isAdvancing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appearance) private var appearance
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var steps: [TutorialScript.Step] { TutorialScript.steps }

    var body: some View {
        VStack(spacing: 0) {
            GameTopBar(model: model, subtitle: Text("Step \(min(stepIndex + 1, steps.count)) of \(steps.count)"))
            GeometryReader { geometry in
                BoardView(
                    model: model,
                    cell: Layout.boardCell(
                        width: geometry.size.width, sizeClass: sizeClass,
                        largerNumbers: appearance.largerNumbers || dynamicTypeSize.isAccessibilitySize
                    ),
                    onTap: { cell in animate { model.tap(cell) } },
                    onDragStart: { cell in animate { model.beginDrag(at: cell) } }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 20)
            explanation
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            GameActionBar(
                model: model,
                onUndo: {},
                onAddNumbers: { animate { model.addNumbers() } },
                onHint: {}
            )
        }
        .frame(maxWidth: Layout.boardWidth(sizeClass) + 48)
        .frame(maxWidth: .infinity)
        .screen {
            if !isFinished {
                Button("Skip", action: onFinish)
                    .font(.headline)
                    .foregroundStyle(appearance.theme.primary)
                    .frame(minWidth: 48, minHeight: 48)
                    .accessibilityIdentifier("skipTutorial")
            }
        }
        .onAppear { if model.guide == nil, !isFinished { guide(steps[stepIndex]) } }
        .onChange(of: model.session) { advanceIfDone() }
        .onChange(of: reduceMotion, initial: true) { model.reduceMotion = reduceMotion }
    }

    // MARK: Steps

    @ViewBuilder
    private var explanation: some View {
        let theme = appearance.theme
        VStack(alignment: .leading, spacing: 8) {
            if isFinished {
                Text("You're ready")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(theme.ink)
                Text("Tap to match, or drag from one number to the other. Hints show a pair for 3 points.")
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button(isFirstRun ? "Start playing" : "Done", action: onFinish)
                    .buttonStyle(CapsuleButtonStyle())
                    .padding(.top, 6)
                    .accessibilityIdentifier("finishTutorial")
            } else {
                let step = steps[stepIndex]
                Text(step.title)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(theme.ink)
                Text(step.text)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .id(isFinished ? 0 : steps[stepIndex].id)
        .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)))
        .accessibilityElement(children: .contain)
    }

    private func guide(_ step: TutorialScript.Step) {
        switch step.move {
        case .pair(let a, let b): model.setGuide(.init(cells: [a, b]))
        case .addNumbers: model.setGuide(.init(cells: [], allowsAdd: true))
        }
        AccessibilityNotification.Announcement(String(localized: step.text)).post()
    }

    /// After a step's move, let its effects play, then point at the next one.
    private func advanceIfDone() {
        guard !isFinished, !isAdvancing, TutorialScript.isDone(steps[stepIndex], on: model.session) else { return }
        isAdvancing = true
        let next = stepIndex + 1
        Task {
            defer { isAdvancing = false }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.8))
            withAnimation(.quiet) {
                if next < steps.count {
                    stepIndex = next
                    guide(steps[next])
                } else {
                    isFinished = true
                    model.setGuide(.init(cells: []))
                }
            }
        }
    }

    private func animate(_ body: () -> Void) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .quiet, body)
    }
}
