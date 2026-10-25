import Observation
import QuietNumbersCore

/// UI state around a `GameSession`: selection, hints, shakes and feedback.
/// Callers wrap mutations in `withAnimation` so Reduce Motion is decided in the view.
@MainActor
@Observable
final class GameModel {
    private(set) var session: GameSession
    private(set) var selectedID: Int?
    private(set) var hintIDs: Set<Int> = []
    /// Bumped per cell on an invalid pair; drives the shake animation.
    private(set) var shakes: [Int: Int] = [:]
    /// Stage reached after clearing a board, shown briefly as a banner.
    var stageBanner: Int?
    /// Bumped on every +, so the board can scroll to the new numbers.
    private(set) var additions = 0

    private let haptics: HapticsService

    init(session: GameSession = GameSession(seed: .random(in: .min ... .max)), haptics: HapticsService = HapticsService()) {
        self.session = session
        self.haptics = haptics
    }

    var canAddNumbers: Bool { session.plusRemaining > 0 && !session.isOver }
    var canUseHint: Bool { session.hintsRemaining > 0 && !session.isOver }
    /// Stuck until the player taps +.
    var needsNumbers: Bool { !session.isOver && !session.hasValidPair }

    func tap(_ cell: Cell) {
        guard !cell.isCleared, !session.isOver else { return }
        guard let selectedID else {
            select(cell.id)
            return
        }
        if selectedID == cell.id {
            self.selectedID = nil
            return
        }

        let stage = session.stage
        guard let outcome = session.match(cellID: selectedID, cell.id) else {
            shakes[selectedID, default: 0] += 1
            shakes[cell.id, default: 0] += 1
            haptics.play(.invalid)
            select(cell.id)
            return
        }

        self.selectedID = nil
        hintIDs = []
        haptics.play(outcome.clearedRows.isEmpty ? .match : .rowCleared)
        if session.stage != stage {
            stageBanner = session.stage
        }
    }

    func addNumbers() {
        guard session.addNumbers() else { return }
        selectedID = nil
        hintIDs = []
        additions += 1
        haptics.play(.select)
    }

    /// Highlights a valid pair. Returns its first cell so the board can scroll to it.
    @discardableResult
    func showHint() -> Int? {
        guard let pair = session.useHint() else { return nil }
        let cells = session.board.cells
        hintIDs = [cells[pair.first].id, cells[pair.second].id]
        selectedID = nil
        return cells[pair.first].id
    }

    func deselect() {
        selectedID = nil
    }

    private func select(_ id: Int) {
        selectedID = id
        haptics.play(.select)
    }
}
