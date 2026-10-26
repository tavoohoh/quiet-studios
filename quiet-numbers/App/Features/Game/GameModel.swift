import Foundation
import Observation
import QuietNumbersCore
import SwiftUI

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

/// The line drawn between a matched pair, in cell units (1 = one cell side).
struct MatchLine: Equatable {
    enum Tier {
        /// Neighbours.
        case subtle
        /// A few cleared cells in between.
        case medium
        /// A long shot.
        case dramatic

        var drawDuration: Double {
            let base = switch self {
            case .subtle: 0.15
            case .medium: 0.22
            case .dramatic: 0.38
            }
            return base * EffectTiming.scale
        }
    }

    /// Drawn from `from` towards `to`.
    struct Segment: Equatable {
        let from: CGPoint
        let to: CGPoint
    }

    let id: Int
    let tier: Tier
    let segments: [Segment]
}

/// UI state around a `GameSession`: selection, hints, shakes, feedback, and the
/// match sequence (line → ghosts → row effect → collapse).
/// Callers wrap mutations in `withAnimation` so Reduce Motion is decided in the view.
@MainActor
@Observable
final class GameModel {
    private(set) var session: GameSession
    /// What the board shows. Trails `session.board` while a match plays out.
    private(set) var board: Board
    private(set) var selectedID: Int?
    private(set) var hintIDs: Set<Int> = []
    /// The pair being connected; looks selected until it turns into ghosts.
    private(set) var connectingIDs: Set<Int> = []
    private(set) var matchLine: MatchLine?
    /// Rows (by first cell id) playing their clear effect before collapsing.
    private(set) var flashingRows: Set<Int> = []
    /// Bumped per cell on an invalid pair; drives the shake animation.
    private(set) var shakes: [Int: Int] = [:]
    /// Stage reached after clearing a board, shown briefly as a banner.
    var stageBanner: Int?
    /// Bumped on every +, so the board can scroll to the new numbers.
    private(set) var additions = 0
    private(set) var scoreChange: ScoreChange?
    private(set) var praise: Praise?
    /// Set by the view; skips the line and shortens the sequence.
    var reduceMotion = false

    private var feedbackID = 0
    private var sequence: Task<Void, Never>?

    /// Cleared cells between a pair for it to count as a long shot.
    private static let longShotGap = 4
    /// Every this many matches in a row earns a praise.
    private static let streakStep = 5
    /// How long a cleared row shows its effect before collapsing.
    private static let rowEffectDuration = 0.45 * EffectTiming.scale
    /// How long a drawn line stays before the numbers turn into ghosts.
    private static let lineHold = 0.08 * EffectTiming.scale
    /// Distance from a cell's center where the line stops, so it doesn't cover the number.
    private static let lineInset = 0.3

    private let haptics: HapticsService

    init(session: GameSession = GameSession(seed: .random(in: .min ... .max)), haptics: HapticsService = HapticsService()) {
        self.session = session
        self.board = session.board
        self.haptics = haptics
    }

    var canAddNumbers: Bool { session.plusRemaining > 0 && !session.isOver }
    var canUseHint: Bool { !session.isOver }
    /// Stuck until the player taps +.
    var needsNumbers: Bool { !session.isOver && !session.hasValidPair }

    func tap(_ cell: Cell) {
        finishSequence()
        guard !session.isOver,
              let index = session.board.index(ofCell: cell.id),
              !session.board.cells[index].isCleared
        else { return }
        guard let selectedID else {
            select(cell.id)
            return
        }
        if selectedID == cell.id {
            self.selectedID = nil
            return
        }

        let before = session.board
        let stage = session.stage
        guard let outcome = session.match(cellID: selectedID, cell.id) else {
            shakes[selectedID, default: 0] += 1
            shakes[cell.id, default: 0] += 1
            session.registerMiss()
            haptics.play(.invalid)
            select(cell.id)
            return
        }

        self.selectedID = nil
        hintIDs = []
        showScoreChange(outcome.points)
        haptics.play(outcome.clearedRows.isEmpty ? .match : .rowCleared)
        if session.stage != stage {
            stageBanner = session.stage
        } else if let text = praiseText(for: outcome) {
            feedbackID += 1
            praise = Praise(id: feedbackID, text: text)
        }
        play(outcome, from: before)
    }

    func addNumbers() {
        finishSequence()
        guard session.addNumbers() else { return }
        board = session.board
        selectedID = nil
        hintIDs = []
        additions += 1
        haptics.play(.select)
    }

    /// Highlights a valid pair, for a few points.
    func showHint() {
        finishSequence()
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

    // MARK: Match sequence

    /// Line → ghosts → row effect → collapse. The session is already updated;
    /// only `board` and the effects trail behind.
    private func play(_ outcome: MatchOutcome, from before: Board) {
        let pair = outcome.pair
        let ghosted = before.clearing([pair.first, pair.second])
        let rowIDs = Set(outcome.clearedRows.map { before.cells[$0 * Board.columns].id })
        let line = makeLine(for: pair)

        board = before
        connectingIDs = [before.cells[pair.first].id, before.cells[pair.second].id]
        matchLine = reduceMotion ? nil : line

        sequence = Task { [weak self] in
            if !(self?.reduceMotion ?? true) {
                try? await Task.sleep(for: .seconds(line.tier.drawDuration + Self.lineHold))
            }
            guard let self, !Task.isCancelled else { return }
            withAnimation(.quiet) {
                self.board = ghosted
                self.connectingIDs = []
                self.matchLine = nil
                self.flashingRows = rowIDs
            }
            if !rowIDs.isEmpty {
                try? await Task.sleep(for: .seconds(Self.rowEffectDuration))
                guard !Task.isCancelled else { return }
            }
            withAnimation(.quiet) { self.finishSequence() }
        }
    }

    /// Jumps to the end of any running match sequence.
    private func finishSequence() {
        sequence?.cancel()
        sequence = nil
        board = session.board
        connectingIDs = []
        flashingRows = []
        matchLine = nil
    }

    private func makeLine(for pair: Pair) -> MatchLine {
        func center(_ index: Int) -> CGPoint {
            CGPoint(x: Double(index % Board.columns) + 0.5, y: Double(index / Board.columns) + 0.5)
        }
        let a = center(pair.first)
        let b = center(pair.second)
        let inset = Self.lineInset
        let segments: [MatchLine.Segment]

        switch pair.route {
        case .readingOrder:
            // End of one row to the start of the next: grow in from both edges.
            segments = [
                .init(from: CGPoint(x: Double(Board.columns), y: a.y), to: CGPoint(x: a.x + inset, y: a.y)),
                .init(from: CGPoint(x: 0, y: b.y), to: CGPoint(x: b.x - inset, y: b.y)),
            ]
        case .line:
            // Grow out from the middle towards both numbers.
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            func stop(at point: CGPoint) -> CGPoint {
                let dx = point.x - mid.x, dy = point.y - mid.y
                let length = max((dx * dx + dy * dy).squareRoot(), .ulpOfOne)
                let keep = max(length - inset, 0) / length
                return CGPoint(x: mid.x + dx * keep, y: mid.y + dy * keep)
            }
            segments = [.init(from: mid, to: stop(at: a)), .init(from: mid, to: stop(at: b))]
        }

        let tier: MatchLine.Tier = switch pair.gap {
        case 0: .subtle
        case ..<Self.longShotGap: .medium
        default: .dramatic
        }
        feedbackID += 1
        return MatchLine(id: feedbackID, tier: tier, segments: segments)
    }

    // MARK: Feedback

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
        let streak = session.streak
        if streak > 0, streak.isMultiple(of: Self.streakStep) { return "\(streak) in a row!" }
        return nil
    }

    private func select(_ id: Int) {
        selectedID = id
        haptics.play(.select)
    }
}
