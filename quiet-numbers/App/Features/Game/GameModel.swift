import Foundation
import Observation
import QuietNumbersCore

/// A score delta shown briefly next to the score ("+4", "-3").
struct ScoreChange: Equatable {
    let id: Int
    let amount: Int
}

/// Short encouragement after a notable move.
struct Praise: Equatable {
    let id: Int
    let text: LocalizedStringResource
}

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
    private(set) var scoreChange: ScoreChange?
    private(set) var praise: Praise?

    /// Valid matches since the last invalid attempt.
    private var streak = 0
    private var feedbackID = 0

    /// Cleared cells between a pair for it to count as a long shot.
    private static let longShotGap = 4
    /// Every this many matches in a row earns a praise.
    private static let streakStep = 5

    private let haptics: HapticsService

    init(session: GameSession = GameSession(seed: .random(in: .min ... .max)), haptics: HapticsService = HapticsService()) {
        self.session = session
        self.haptics = haptics
    }

    var canAddNumbers: Bool { session.plusRemaining > 0 && !session.isOver }
    var canUseHint: Bool { !session.isOver }
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
            streak = 0
            haptics.play(.invalid)
            select(cell.id)
            return
        }

        self.selectedID = nil
        hintIDs = []
        streak += 1
        showScoreChange(outcome.points)
        haptics.play(outcome.clearedRows.isEmpty ? .match : .rowCleared)
        if session.stage != stage {
            stageBanner = session.stage
        } else if let text = praiseText(for: outcome) {
            feedbackID += 1
            praise = Praise(id: feedbackID, text: text)
        }
    }

    func addNumbers() {
        guard session.addNumbers() else { return }
        selectedID = nil
        hintIDs = []
        additions += 1
        haptics.play(.select)
    }

    /// Highlights a valid pair, for a few points.
    func showHint() {
        guard let hint = session.useHint() else { return }
        let cells = session.board.cells
        hintIDs = [cells[hint.pair.first].id, cells[hint.pair.second].id]
        selectedID = nil
        if hint.cost > 0 {
            showScoreChange(-hint.cost)
        }
    }

    func dismissScoreChange(_ change: ScoreChange) {
        if scoreChange == change { scoreChange = nil }
    }

    func dismissPraise(_ shown: Praise) {
        if praise == shown { praise = nil }
    }

    private func showScoreChange(_ amount: Int) {
        feedbackID += 1
        scoreChange = ScoreChange(id: feedbackID, amount: amount)
    }

    private func praiseText(for outcome: MatchOutcome) -> LocalizedStringResource? {
        switch outcome.clearedRows.count {
        case 3...: return "Triple row!"
        case 2: return "Double row!"
        default: break
        }
        if outcome.pair.gap >= Self.longShotGap { return "Long shot!" }
        if streak.isMultiple(of: Self.streakStep) { return "\(streak) in a row!" }
        return nil
    }

    private func select(_ id: Int) {
        selectedID = id
        haptics.play(.select)
    }
}
