import Observation
import QuietSolitaireCore
import QuietUI
import SwiftUI

/// The game on screen: wraps `GameSession` with what the board shows around it
/// (hint highlights, invalid shakes, auto-complete, the "no way out" notice).
@MainActor
@Observable
final class GameModel {
    private(set) var session: GameSession
    /// The suggested move, shown for a moment after a hint.
    private(set) var hint: Move?
    /// Cards that just bounced back from an illegal drop.
    private(set) var rejected: Set<Int> = []
    /// Cards moved by the last play: drawn above the rest while they travel.
    private(set) var inFlight: Set<Int> = []
    private(set) var isAutoCompleting = false
    /// The solver proved there's no win left from here.
    private(set) var isStuck = false
    private(set) var isFindingHint = false
    /// The player chose to keep playing a lost game: no more notices for it.
    private var keepsPlayingLostGame = false
    /// Hint found nothing to do (shown as a short note).
    private(set) var hintNote: LocalizedStringResource?
    /// The last milestone, shown for a moment (a burst on the foundation, a toast).
    private(set) var milestone: Milestone?

    enum Milestone: Equatable {
        /// A suit reached its king.
        case foundationComplete(Suit)
        /// No face-down card left in the tableau.
        case allRevealed
    }

    /// Achievements and progress (`AppModel.record`).
    var onProgress: ((ProgressEvent) -> Void)?
    /// After every change, to save.
    var onChange: (() -> Void)?

    /// Tutorial: the only move allowed, ringed like a hint until it's played.
    private(set) var guide: Move?
    /// Tutorial tables aren't meant to be won: no "no way out" notice.
    let isTutorial: Bool

    private var stuckCheck: Task<Void, Never>?

    init(session: GameSession, isTutorial: Bool = false) {
        self.session = session
        self.isTutorial = isTutorial
        checkStuck()
    }

    func setGuide(_ move: Move?) {
        guide = move
    }

    /// Outside the tutorial everything legal goes; in it, only the guided move (nothing
    /// between steps).
    private func isAllowed(_ move: Move) -> Bool {
        isTutorial ? guide == move : true
    }

    var state: GameState { session.state }

    // MARK: Finding cards

    /// Where a card is and how many cards a drag from it would carry.
    func locate(_ cardID: Int) -> (location: Location, count: Int)? {
        let state = session.state
        if state.waste.last?.id == cardID { return (.waste, 1) }
        for suit in Suit.allCases where state.foundation(suit).last?.id == cardID { return (.foundation(suit), 1) }
        for column in 0..<7 {
            if let index = state.tableau[column].firstIndex(where: { $0.card.id == cardID }),
               let length = state.runLength(column: column, from: index) {
                return (.tableau(column), length)
            }
        }
        return nil
    }

    func isInStock(_ cardID: Int) -> Bool { session.state.stock.contains { $0.id == cardID } }

    /// Cards that travel with a drag that starts on `cardID`.
    func carried(from cardID: Int) -> [Int] {
        guard let (location, count) = locate(cardID) else { return [] }
        if case .tableau(let column) = location {
            return session.state.tableau[column].suffix(count).map(\.card.id)
        }
        return [cardID]
    }

    // MARK: Playing

    func drawFromStock() {
        guard isAllowed(.draw) else { return FeedbackService.shared.play(.invalid) }
        play(.draw)
    }

    /// A tap on a face-up card sends it (and the run on it) to its best place.
    func tap(_ cardID: Int) {
        guard let (location, count) = locate(cardID) else { return }
        if let destination = session.state.bestDestination(from: location, count: count),
           isAllowed(.move(from: location, count: count, to: destination)) {
            play(.move(from: location, count: count, to: destination))
        } else {
            reject(carried(from: cardID))
        }
    }

    /// A drop: plays if legal, otherwise the cards bounce back.
    @discardableResult
    func drop(_ cardID: Int, on destination: Location) -> Bool {
        guard let (location, count) = locate(cardID) else { return false }
        let move = Move.move(from: location, count: count, to: destination)
        guard session.state.isLegal(move), isAllowed(move) else {
            if destination != location { reject(carried(from: cardID)) }
            return false
        }
        play(move)
        return true
    }

    func undo() {
        guard session.canUndo else { return }
        withAnimation(.spring(duration: 0.28)) {
            session.undo()
            hint = nil
        }
        FeedbackService.shared.play(.place)
        changed()
    }

    private func play(_ move: Move) {
        let foundationsBefore = session.state.foundations.map(\.count)
        let faceDownBefore = faceDownCount
        var events: [GameSession.Event]?
        withAnimation(.spring(duration: 0.28, bounce: 0.12)) {
            inFlight = movedIDs(for: move)
            events = session.play(move)
            hint = nil
        }
        guard let events else { return FeedbackService.shared.play(.invalid) }
        let completedSuit = Suit.allCases.first { foundationsBefore[$0.rawValue] != 13 && session.state.foundation($0).count == 13 }
        let completed = completedSuit != nil
        if !session.isWon, !isAutoCompleting {
            if let completedSuit { show(.foundationComplete(completedSuit)) }
            if faceDownBefore > 0, faceDownCount == 0 { show(.allRevealed) }
        }
        switch move {
        case .move(_, _, .foundation): FeedbackService.shared.play(completed ? .foundationComplete : .toFoundation)
        default: FeedbackService.shared.play(.place)
        }
        for event in events {
            switch event {
            case .ladder: onProgress?(.ladder)
            case .won(let summary):
                FeedbackService.shared.play(.won)
                onProgress?(.won(summary, isClassic: session.mode == .classic))
            case .moved, .hintCharged: break
            }
        }
        changed()
    }

    private func movedIDs(for move: Move) -> Set<Int> {
        switch move {
        case .draw:
            return Set(session.state.stock.last.map { [$0.id] } ?? session.state.waste.map(\.id))
        case .move(let from, let count, _):
            switch from {
            case .waste: return Set(session.state.waste.suffix(1).map(\.id))
            case .foundation(let suit): return Set(session.state.foundation(suit).suffix(1).map(\.id))
            case .tableau(let column): return Set(session.state.tableau[column].suffix(count).map(\.card.id))
            }
        }
    }

    private var faceDownCount: Int {
        session.state.tableau.reduce(0) { $0 + $1.filter { !$0.isFaceUp }.count }
    }

    private func show(_ milestone: Milestone) {
        withAnimation(.quiet) { self.milestone = milestone }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if self.milestone == milestone { withAnimation(.quiet) { self.milestone = nil } }
        }
    }

    private func reject(_ ids: [Int]) {
        FeedbackService.shared.play(.invalid)
        rejected = Set(ids)
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            rejected = []
        }
    }

    private func changed() {
        onChange?()
        checkStuck()
    }

    /// One second of play (the game screen ticks it while the app is active). Not saved
    /// on every tick: the next move, leaving the game or the app going to background saves it.
    func tick() {
        session.tick()
    }

    func keepPlaying() {
        withAnimation(.quiet) {
            keepsPlayingLostGame = true
            isStuck = false
        }
    }

    // MARK: Help

    /// Finds the solver's next move (off the main thread), charges for it and shows it.
    func requestHint() async {
        guard !isFindingHint, !session.isWon else { return }
        isFindingHint = true
        let state = session.state
        let move = await Task.detached(priority: .userInitiated) { GameSession.suggestion(for: state) }.value
        isFindingHint = false
        guard state == session.state else { return }
        guard let move else {
            hintNote = "No moves left. Try undo."
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                hintNote = nil
            }
            return
        }
        let event = session.chargeHint()
        if case .hintCharged(let score) = event { onProgress?(.hintCharged(scoreAfter: score)) }
        FeedbackService.shared.play(.hint)
        hint = move
        changed()
        try? await Task.sleep(for: .seconds(1.8))
        if hint == move { hint = nil }
    }

    var canAutoComplete: Bool { session.state.canAutoComplete && !isAutoCompleting }

    /// Plays every remaining card to the foundations, one at a time.
    func autoComplete() async {
        guard canAutoComplete else { return }
        isAutoCompleting = true
        while let move = session.state.autoCompleteMove {
            play(move)
            try? await Task.sleep(for: .milliseconds(90))
        }
        isAutoCompleting = false
    }

    /// Asks the solver (in the background) whether any win is left. Only a proof counts:
    /// running out of budget never declares a game lost.
    private func checkStuck() {
        stuckCheck?.cancel()
        isStuck = false
        let state = session.state
        guard !state.isWon, !isTutorial, !keepsPlayingLostGame else { return }
        stuckCheck = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .utility) { Solver.solve(state, budget: Solver.quickBudget) }.value
            guard !Task.isCancelled, state == session.state else { return }
            withAnimation(.quiet) { isStuck = result == .unsolvable }
        }
    }
}
