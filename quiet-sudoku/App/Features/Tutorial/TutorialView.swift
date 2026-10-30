import QuietSudokuCore
import QuietUI
import SwiftUI

/// Interactive tutorial for someone who has never played: one board per lesson
/// (`Tutorial.lessons`), the cell to fill selected and its house highlighted, and only the
/// right answer counts. Shown before the first game and from Settings › How to play.
/// Nothing here counts for progress.
struct TutorialView: View {
    /// First run: ends by starting a game. From Settings: ends by going back.
    let isFirstRun: Bool
    let onFinish: () -> Void

    @State private var stepIndex = 0
    @State private var model = TutorialView.model(for: 0)
    @State private var isFinished = false
    @State private var isAdvancing = false

    @Environment(\.quietTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    private static var lessons: [Tutorial.Lesson] { Tutorial.lessons }

    private static func model(for index: Int) -> GameModel {
        let lesson = lessons[index]
        let model = GameModel(session: GameSession(puzzle: lesson.puzzle), isTutorial: true)
        model.setGuide(GameModel.Guide(
            cell: lesson.target,
            digits: lesson.kind == .notes ? lesson.notes : lesson.kind == .hint ? [] : [lesson.digit],
            asNotes: lesson.kind == .notes,
            units: lesson.units,
            // Rows, columns and boxes speak for themselves; rings only where they explain.
            clues: [.crossHatch, .onlyOne].contains(lesson.kind) ? lesson.clues : []
        ))
        return model
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Step \(min(stepIndex + 1, Self.lessons.count)) of \(Self.lessons.count)")
                .font(.counter)
                .foregroundStyle(theme.muted)
                .padding(.top, 4)
            GeometryReader { geometry in
                let size = min(geometry.size.width - 16, Layout.boardWidth(sizeClass), geometry.size.height)
                BoardView(model: model, size: size)
                    .id(stepIndex)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 10)
            explanation
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            if !isFinished { controls }
        }
        .screen(Text("How to play")) {
            if !isFinished {
                Button("Skip", action: onFinish)
                    .font(.headline)
                    .foregroundStyle(theme.primary)
                    .frame(minWidth: 48, minHeight: 48)
                    .accessibilityIdentifier("skipTutorial")
            }
        }
        .onAppear { announce() }
        .onChange(of: model.session) { advanceIfDone() }
    }

    private var lesson: Tutorial.Lesson { Self.lessons[stepIndex] }

    /// Notes and Hint (each only in its lesson), then the keypad.
    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if lesson.kind == .notes {
                    Toggle(isOn: Bindable(model).isNoting) { Label("Notes", systemImage: "pencil") }
                        .toggleStyle(.button)
                        .buttonStyle(CapsuleButtonStyle(isProminent: model.isNoting))
                        .accessibilityIdentifier("notes")
                }
                if lesson.kind == .hint {
                    Button { model.requestHint() } label: { Label("Hint", systemImage: "lightbulb") }
                        .buttonStyle(CapsuleButtonStyle())
                        .accessibilityIdentifier("hint")
                }
            }
            HStack(spacing: 6) {
                ForEach(1...9, id: \.self) { digit in
                    Button { model.input(digit) } label: {
                        Text(verbatim: "\(digit)")
                            .font(.system(size: model.isNoting ? 22 : 30, weight: .medium, design: .rounded))
                            .foregroundStyle(model.isNoting ? theme.muted : theme.primary)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                    }
                    .buttonStyle(.plain)
                    .disabled(lesson.kind == .hint)
                    .accessibilityIdentifier("digit-\(digit)")
                }
            }
            .frame(maxWidth: Layout.boardWidth(sizeClass))
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isFinished {
                Text("You're ready")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(theme.ink)
                Text("Fill every row, column and box with 1 to 9. Start with an easy one: it needs only what you just learned.")
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button(isFirstRun ? "Start playing" : "Done", action: onFinish)
                    .buttonStyle(CapsuleButtonStyle())
                    .padding(.top, 6)
                    .accessibilityIdentifier("finishTutorial")
            } else {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(theme.ink)
                Text(text)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if model.hint != nil {
                    Text(model.hint!.body)
                        .font(.subheadline)
                        .foregroundStyle(theme.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
        .id(isFinished ? -1 : stepIndex)
        .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tutorialText")
    }

    private var title: LocalizedStringResource {
        switch lesson.kind {
        case .row: "Each row holds 1 to 9"
        case .column: "Columns too"
        case .box: "And boxes"
        case .crossHatch: "Only place"
        case .onlyOne: "Only digit"
        case .notes: "Notes"
        case .hint: "Mistakes and hints"
        }
    }

    private var text: LocalizedStringResource {
        switch lesson.kind {
        case .row: "Every row needs the digits 1 to 9, once each. This row is missing one: tap it on the keypad."
        case .column: "Every column also needs 1 to 9 once. Which digit is missing from this column?"
        case .box: "Each 3×3 box needs 1 to 9 once too. Fill the empty cell of this box."
        case .crossHatch: "Find where the \(lesson.digit) goes in this box. The ringed \(lesson.digit)s rule out every other empty cell: their rows and columns already have one."
        case .onlyOne: "This cell's row, column and box already hold eight different digits. Which one is left?"
        case .notes: "Not sure yet? Take notes. With Notes on, tap \(lesson.notes.map(String.init).formatted(.list(type: .and))): the digits that could still go here."
        case .hint: "A wrong digit is a mistake: it costs 20 points, and the game goes on. Stuck? Tap Hint: it writes the next digit and says why, for 10 points."
        }
    }

    private var isLessonDone: Bool {
        let session = model.session
        return switch lesson.kind {
        case .notes: Digits.list(session.notes[lesson.target]) == lesson.notes
        case .hint: session.hintsUsed > 0
        default: session.values[lesson.target] == lesson.digit
        }
    }

    private func announce() {
        guard !isFinished else { return }
        AccessibilityNotification.Announcement(String(localized: text)).post()
    }

    /// After a lesson's answer, the next board.
    private func advanceIfDone() {
        guard !isFinished, !isAdvancing, isLessonDone else { return }
        isAdvancing = true
        FeedbackService.shared.play(.unitComplete)
        let next = stepIndex + 1
        Task {
            defer { isAdvancing = false }
            // The hint lesson leaves its explanation up a little longer.
            try? await Task.sleep(for: .seconds(lesson.kind == .hint ? 2.4 : reduceMotion ? 0.3 : 0.8))
            withAnimation(.quiet) {
                if next < Self.lessons.count {
                    stepIndex = next
                    model = Self.model(for: next)
                    announce()
                } else {
                    isFinished = true
                }
            }
        }
    }
}
