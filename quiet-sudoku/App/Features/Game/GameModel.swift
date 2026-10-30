import Observation
import QuietSudokuCore
import QuietUI
import SwiftUI

/// The game on screen: wraps `GameSession` with what the board shows around it (the
/// selected cell, notes mode, the hint's explanation, shakes and flashes).
@MainActor
@Observable
final class GameModel {
    private(set) var session: GameSession
    var selected: Int?
    /// Digits go in as pencil marks.
    var isNoting = false
    /// The last hint, explained under the board until the next action.
    private(set) var hint: GameSession.Hint?
    /// A cell that just took a wrong digit (shakes).
    private(set) var shaking: Int?
    /// Houses just completed, lit for a moment.
    private(set) var flashing: [Int] = []
    /// With "Show mistakes right away" off: the wrong digits found when the board filled
    /// up, red until corrected.
    private(set) var revealed: Set<Int> = []
    /// "3 digits don't fit. Fix them." and other short notes.
    private(set) var note: LocalizedStringResource?
    /// Wrong digits turn red as soon as they're written.
    var showsMistakes = true

    /// Achievements and progress (`AppModel.record`).
    var onProgress: ((ProgressEvent) -> Void)?
    /// After every change, to save.
    var onChange: (() -> Void)?

    /// Tutorial: only this cell can be selected, and only these digits written.
    private(set) var guide: Guide?
    let isTutorial: Bool

    struct Guide: Equatable {
        let cell: Int
        let digits: [Int]
        let asNotes: Bool
        /// Highlighted like a hint: the houses and the cells that explain the answer.
        var units: [Int] = []
        var clues: [Int] = []
    }

    init(session: GameSession, isTutorial: Bool = false) {
        self.session = session
        self.isTutorial = isTutorial
    }

    func setGuide(_ guide: Guide?) {
        self.guide = guide
        if let guide {
            selected = guide.cell
            isNoting = guide.asNotes
        }
    }

    // MARK: What the board shows

    /// Red: wrong, and either shown right away or found when the board filled up.
    func showsWrong(_ cell: Int) -> Bool {
        session.isWrong(cell) && (showsMistakes || revealed.contains(cell))
    }

    /// The score as shown: without mistake costs while mistakes are hidden.
    var shownScore: Int {
        showsMistakes || session.isWon ? session.score : session.scoreHidingMistakes
    }

    var selectedDigit: Int? {
        selected.flatMap { session.values[$0] == 0 ? nil : session.values[$0] }
    }

    // MARK: Playing

    func select(_ cell: Int) {
        if let guide, guide.cell != cell { return FeedbackService.shared.play(.invalid) }
        selected = cell
        FeedbackService.shared.play(.select)
    }

    /// Arrow keys: moves the selection, wrapping around the edges.
    func moveSelection(rows: Int, columns: Int) {
        guard guide == nil else { return }
        let cell = selected ?? 40
        let row = (Grid.row(of: cell) + rows + 9) % 9
        let column = (Grid.column(of: cell) + columns + 9) % 9
        selected = Grid.cell(row: row, column: column)
    }

    /// A keypad digit: a note in notes mode, otherwise the cell's digit.
    func input(_ digit: Int) {
        guard let cell = selected else { return FeedbackService.shared.play(.invalid) }
        if let guide, !guide.digits.contains(digit) || guide.asNotes != isNoting {
            return reject(cell)
        }
        if isNoting {
            guard session.values[cell] == 0, session.toggleNote(digit, at: cell) else { return reject(cell) }
            FeedbackService.shared.play(.select)
            return changed()
        }
        var events: [GameSession.Event]?
        withAnimation(.spring(duration: 0.25, bounce: 0.2)) {
            events = session.place(digit, at: cell)
            hint = nil
        }
        guard let events else { return reject(cell) }
        handle(events)
        changed()
    }

    func erase() {
        guard let cell = selected, guide == nil else { return }
        guard session.erase(cell) else { return reject(cell) }
        revealed.remove(cell)
        hint = nil
        FeedbackService.shared.play(.select)
        changed()
    }

    func undo() {
        guard session.canUndo, guide == nil else { return }
        withAnimation(.quiet) {
            session.undo()
            hint = nil
        }
        revealed = revealed.filter(session.isWrong)
        FeedbackService.shared.play(.place)
        changed()
    }

    // MARK: Help

    /// Charges a hint and does it: clears a wrong digit or writes the next one by logic.
    /// The explanation stays under the board until the next action.
    func requestHint() {
        guard !session.isWon, let next = session.hint() else { return }
        if guide != nil, case .mistake = next { return }
        var events: [GameSession.Event] = []
        withAnimation(.quiet) {
            events = session.apply(next)
            hint = next
        }
        switch next {
        case .mistake(let cell):
            selected = cell
            revealed.remove(cell)
        case .step(let step, _):
            selected = step.placement?.cell
        }
        FeedbackService.shared.play(.hint)
        handle(events)
        changed()
    }

    func dismissHint() {
        withAnimation(.quiet) { hint = nil }
    }

    /// One second of play (the game screen ticks it while the app is active). Not saved
    /// on every tick: the next action, leaving the game or the app going to background saves it.
    func tick() {
        session.tick()
    }

    // MARK: Private

    private func handle(_ events: [GameSession.Event]) {
        var completed: [Int] = []
        for event in events {
            switch event {
            case .placed:
                FeedbackService.shared.play(.place)
            case .mistake(let cell, let score):
                if showsMistakes {
                    FeedbackService.shared.play(.invalid)
                    shake(cell)
                } else {
                    // Hidden mistakes sound like any other digit.
                    FeedbackService.shared.play(.place)
                }
                onProgress?(.scoreChanged(score))
            case .hintCharged(let score):
                onProgress?(.scoreChanged(score))
            case .completed(let units):
                completed += units
            case .digitDone:
                break
            case .won(let summary):
                FeedbackService.shared.play(.won)
                selected = nil
                onProgress?(.won(summary, isClassic: session.mode == .classic))
            }
        }
        if !completed.isEmpty, !session.isWon {
            FeedbackService.shared.play(.unitComplete)
            flash(completed)
        }
        // Mistakes hidden: a full board that isn't solved shows what's wrong.
        if !showsMistakes, session.isFull, !session.isWon {
            let wrong = Set(session.wrongCells)
            revealed = wrong
            show("\(wrong.count) digits don't fit. Fix them.")
        }
    }

    private func reject(_ cell: Int) {
        FeedbackService.shared.play(.invalid)
        shake(cell)
    }

    private func shake(_ cell: Int) {
        shaking = cell
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            if shaking == cell { shaking = nil }
        }
    }

    private func flash(_ units: [Int]) {
        withAnimation(.easeOut(duration: 0.15)) { flashing = units }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeIn(duration: 0.35)) { flashing = [] }
        }
    }

    private func show(_ text: LocalizedStringResource) {
        withAnimation(.quiet) { note = text }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if note == text { withAnimation(.quiet) { note = nil } }
        }
    }

    private func changed() {
        onChange?()
    }
}
