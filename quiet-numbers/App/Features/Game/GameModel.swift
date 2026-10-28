import Foundation
import Observation
import QuietNumbersCore
import QuietUI
import SwiftUI

/// A score delta shown briefly next to the score ("+4", "-3").
struct ScoreChange: Equatable {
    let id: Int
    let amount: Int
}

/// Points from a match: "+4" rises from the middle of the pair and fades.
struct FloatingPoints: Equatable, Identifiable {
    let id: Int
    let amount: Int
    /// Midpoint of the pair, in cell units.
    let center: CGPoint
    /// Waits for the line first.
    let delay: Double

    static let duration = 0.6 * EffectTiming.scale
}

/// Short encouragement after a notable move, as a toast next to the score.
struct Praise: Equatable {
    let id: Int
    let text: LocalizedStringResource
    var delay: Double = 0
}

/// A matched number bursting into 8 rays (in the accent color for a long shot).
struct Pop: Equatable, Identifiable {
    let id: Int
    /// Cell center, in cell units.
    let center: CGPoint
    let isLongShot: Bool

    static let duration = 0.26 * EffectTiming.scale
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

        var drawDuration: Double { 0.12 * EffectTiming.scale }
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
    /// The two cells of an invalid pair, ringed in the accent color for a moment.
    private(set) var missIDs: Set<Int> = []
    /// First cell added by the last +, so new numbers can come in one by one.
    private(set) var addedFromID: Int?
    /// Stage reached after clearing a board, shown briefly as a banner.
    var stageBanner: Int?
    /// Bumped on every +, so the board can scroll to the new numbers.
    private(set) var additions = 0
    /// Next to the score: hint costs and undos (and every change under Reduce Motion).
    private(set) var scoreChange: ScoreChange?
    private(set) var floatingPoints: FloatingPoints?
    /// Bursts playing on the matched cells.
    private(set) var pops: [Pop] = []
    /// Points of the match playing out; the score shown counts them in after the line.
    private var pendingPoints = 0
    private(set) var praise: Praise?
    /// Bumped when a hint finds nothing and + is the way out; bounces the + button.
    private(set) var plusNudges = 0
    /// Tutorial: only these cells can be played (ringed like a hint), and + only when
    /// `allowsAdd`. Undo and hints are off. `nil` is free play.
    private(set) var guide: Guide?
    /// Bumped when a tap misses the guided pair, so its rings blink again.
    private(set) var guideNudges = 0
    /// Set by the view; skips the line and shortens the sequence.
    var reduceMotion = false
    /// Gameplay events for achievements.
    var onEvent: ((ProgressEvent) -> Void)?

    private var feedbackID = 0
    /// Seconds played since the session last got them (`commitTime`).
    private var uncommittedSeconds = 0
    private var sequence: Task<Void, Never>?
    private var missTask: Task<Void, Never>?
    /// The last move if it was a match, so undoing it can take its progress back.
    private var lastOutcome: MatchOutcome?

    /// Cleared cells between a pair for it to count as a long shot.
    private static let longShotGap = 4
    /// Every this many matches in a row earns a praise.
    private static let streakStep = 5
    /// How long a cleared row shows its effect before collapsing, and the collapse itself.
    private static let rowEffectDuration = 0.15 * EffectTiming.scale
    private static let rowCollapse = Animation.easeInOut(duration: 0.28 * EffectTiming.scale)
    /// Distance from a cell's center where the line stops, so it doesn't cover the number.
    private static let lineInset = 0.3

    private let feedback: FeedbackService

    init(session: GameSession = GameSession(seed: .random(in: .min ... .max)), feedback: FeedbackService = .shared) {
        self.session = session
        self.board = session.board
        self.feedback = feedback
    }

    struct Guide: Equatable {
        var cells: Set<Int>
        var allowsAdd = false
    }

    var canAddNumbers: Bool { session.plusRemaining > 0 && !session.isOver && (guide?.allowsAdd ?? true) }
    var canUseHint: Bool { !session.isOver && guide == nil }
    var canUndo: Bool { session.canUndo && guide == nil }
    /// Stuck until the player taps +.
    var needsNumbers: Bool { !session.isOver && !session.hasValidPair }
    var displayedScore: Int { session.score - pendingPoints }

    func tap(_ cell: Cell) {
        finishSequence()
        commitTime()
        guard !session.isOver,
              let index = session.board.index(ofCell: cell.id),
              !session.board.cells[index].isCleared
        else { return }
        if let guide, !guide.cells.contains(cell.id) {
            guideNudges += 1
            feedback.play(.select)
            return
        }
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
            miss(selectedID, cell.id)
            return
        }

        self.selectedID = nil
        hintIDs = []
        let effectsDelay = reduceMotion ? 0 : Self.tier(for: outcome.pair).drawDuration
        if reduceMotion {
            showScoreChange(outcome.points)
        } else {
            feedbackID += 1
            pendingPoints = outcome.points
            let a = Self.center(of: outcome.pair.first), b = Self.center(of: outcome.pair.second)
            floatingPoints = FloatingPoints(
                id: feedbackID, amount: outcome.points,
                center: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), delay: effectsDelay
            )
        }
        feedback.play(
            outcome.boardCleared ? .boardCleared
                : outcome.clearedRows.isEmpty ? .match(longShot: Self.isLongShot(outcome.pair))
                : .rowCleared
        )
        onEvent?(.matched(outcome))
        lastOutcome = outcome
        if outcome.reachedGoal {
            feedbackID += 1
            praise = Praise(id: feedbackID, text: "Goal reached!", delay: effectsDelay)
        }
        if session.stage != stage {
            stageBanner = session.stage
        } else if !outcome.reachedGoal, let text = praiseText(for: outcome) {
            feedbackID += 1
            praise = Praise(id: feedbackID, text: text, delay: effectsDelay)
        }
        play(outcome, from: before)
    }

    func addNumbers() {
        finishSequence()
        commitTime()
        let firstNewID = session.board.cells.count
        guard session.addNumbers() else { return }
        lastOutcome = nil
        addedFromID = session.board.cells.indices.contains(firstNewID) ? session.board.cells[firstNewID].id : nil
        board = session.board
        selectedID = nil
        hintIDs = []
        additions += 1
        feedback.play(.select)
    }

    /// Drag started on a number: it becomes the selection, replacing any other.
    func beginDrag(at cell: Cell) {
        finishSequence()
        guard !session.isOver, selectedID != cell.id,
              let index = session.board.index(ofCell: cell.id), !session.board.cells[index].isCleared,
              guide?.cells.contains(cell.id) ?? true
        else { return }
        select(cell.id)
    }

    /// Tutorial: points at the next move.
    func setGuide(_ guide: Guide?) {
        self.guide = guide
        hintIDs = guide?.cells ?? []
        selectedID = nil
    }

    /// Highlights a valid pair, for a few points.
    func showHint() {
        finishSequence()
        commitTime()
        guard let hint = session.useHint() else {
            if canAddNumbers {
                plusNudges += 1
                feedbackID += 1
                praise = Praise(id: feedbackID, text: "No pairs. Try +")
                feedback.play(.select)
            }
            return
        }
        let cells = session.board.cells
        hintIDs = [cells[hint.pair.first].id, cells[hint.pair.second].id]
        selectedID = nil
        showScoreChange(-hint.cost)
        feedback.play(.select)
        onEvent?(.hintUsed(scoreAfter: session.score))
    }

    /// Takes back the last match or + (one step).
    func undo() {
        finishSequence()
        commitTime()
        let scoreBefore = session.score
        guard session.undo() else { return }
        if let outcome = lastOutcome { onEvent?(.undone(outcome)) }
        lastOutcome = nil
        board = session.board
        selectedID = nil
        hintIDs = []
        if session.score != scoreBefore { showScoreChange(session.score - scoreBefore) }
        feedback.play(.select)
    }

    /// One second on screen with the app active (the game view ticks it). Kept here and
    /// handed to the session with the next move, so the game isn't saved every second.
    func tick() {
        uncommittedSeconds += 1
    }

    /// Hands the seconds played to the session. Returns whether that changed it (the caller
    /// saves when leaving the game or going to the background).
    @discardableResult
    func commitTime() -> Bool {
        defer { uncommittedSeconds = 0 }
        let before = session.elapsedSeconds
        session.addTime(uncommittedSeconds)
        return session.elapsedSeconds != before
    }

    func dismissScoreChange(_ change: ScoreChange) {
        if scoreChange == change { scoreChange = nil }
    }

    func dismissFloatingPoints(_ shown: FloatingPoints) {
        if floatingPoints == shown { floatingPoints = nil }
    }

    func dismissPraise(_ shown: Praise) {
        if praise == shown { praise = nil }
    }

    // MARK: Match sequence

    /// Line → pops and ghosts → row effect → collapse. The session is already updated;
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
                try? await Task.sleep(for: .seconds(line.tier.drawDuration))
            }
            guard let self, !Task.isCancelled else { return }
            // The pair fades to ghosts while the score counts the points in.
            withAnimation(.easeOut(duration: (self.reduceMotion ? 0.15 : 0.2) * EffectTiming.scale)) {
                self.board = ghosted
                self.connectingIDs = []
                self.matchLine = nil
            }
            withAnimation(.easeOut(duration: 0.3 * EffectTiming.scale)) { self.pendingPoints = 0 }
            if !self.reduceMotion {
                let isLongShot = Self.isLongShot(pair)
                self.pops = [pair.first, pair.second].map { index in
                    self.feedbackID += 1
                    return Pop(id: self.feedbackID, center: Self.center(of: index), isLongShot: isLongShot)
                }
                try? await Task.sleep(for: .seconds(Pop.duration))
                guard !Task.isCancelled else { return }
                self.pops = []
            }
            if !rowIDs.isEmpty {
                withAnimation(.easeOut(duration: Self.rowEffectDuration)) { self.flashingRows = rowIDs }
                try? await Task.sleep(for: .seconds(Self.rowEffectDuration))
                guard !Task.isCancelled else { return }
            }
            withAnimation(rowIDs.isEmpty ? .quiet : Self.rowCollapse) { self.finishSequence() }
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
        pops = []
        pendingPoints = 0
    }

    private static func center(of index: Int) -> CGPoint {
        CGPoint(x: Double(index % Board.columns) + 0.5, y: Double(index / Board.columns) + 0.5)
    }

    private func makeLine(for pair: Pair) -> MatchLine {
        let a = Self.center(of: pair.first)
        let b = Self.center(of: pair.second)
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

        feedbackID += 1
        return MatchLine(id: feedbackID, tier: Self.tier(for: pair), segments: segments)
    }

    /// Four or more cleared cells in between: the line, rays and "Long shot!" get louder.
    private static func isLongShot(_ pair: Pair) -> Bool { pair.gap >= longShotGap }

    private static func tier(for pair: Pair) -> MatchLine.Tier {
        switch pair.gap {
        case 0: .subtle
        case ..<longShotGap: .medium
        default: .dramatic
        }
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
        if Self.isLongShot(outcome.pair) { return "Long shot!" }
        // The tutorial board has few of each digit; "No more 8s!" would only distract there.
        if let digit = outcome.clearedDigits.first, !outcome.boardCleared, guide == nil { return "No more \(digit)s!" }
        let streak = session.streak
        if streak > 0, streak.isMultiple(of: Self.streakStep) { return "\(streak) in a row!" }
        return nil
    }

    /// Not a pair: both rings turn to the accent and shake, then the tapped number stays selected.
    private func miss(_ firstID: Int, _ secondID: Int) {
        shakes[firstID, default: 0] += 1
        shakes[secondID, default: 0] += 1
        missIDs = [firstID, secondID]
        selectedID = secondID
        session.registerMiss()
        onEvent?(.missed)
        feedback.play(.invalid)
        missTask?.cancel()
        missTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.24 * EffectTiming.scale))
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.15 * EffectTiming.scale)) { self.missIDs = [] }
        }
    }

    private func select(_ id: Int) {
        selectedID = id
        feedback.play(.select)
    }
}
