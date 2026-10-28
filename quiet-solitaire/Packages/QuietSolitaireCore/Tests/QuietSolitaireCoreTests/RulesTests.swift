import Foundation
import QuietCore
import Testing
@testable import QuietSolitaireCore

/// Builds a table from short strings: "K♠" etc. Columns list face-down cards with "?" prefix.
func card(_ text: String) -> Card {
    let suits: [Character: Suit] = ["♠": .spades, "♥": .hearts, "♦": .diamonds, "♣": .clubs]
    let ranks = ["A": 1, "J": 11, "Q": 12, "K": 13]
    let symbol = text.last!
    let rankText = String(text.dropLast())
    return Card(ranks[rankText] ?? Int(rankText)!, suits[symbol]!)
}

func column(_ items: String...) -> [TableauCard] {
    items.map { $0.hasPrefix("?") ? TableauCard(card(String($0.dropFirst())), faceUp: false) : TableauCard(card($0), faceUp: true) }
}

func table(stock: [String] = [], waste: [String] = [], foundations: [Int] = [0, 0, 0, 0], _ columns: [TableauCard]...) -> GameState {
    var tableau = columns
    while tableau.count < 7 { tableau.append([]) }
    let piles = Suit.allCases.map { suit in (0..<foundations[suit.rawValue]).map { Card($0 + 1, suit) } }
    return GameState(stock: stock.map(card), waste: waste.map(card), foundations: piles, tableau: tableau)
}

@Suite struct RulesTests {
    @Test func dealHasSevenColumnsAndTwentyFourInStock() {
        let state = GameState.deal(seed: 42)
        #expect(state.tableau.map(\.count) == [1, 2, 3, 4, 5, 6, 7])
        #expect(state.tableau.allSatisfy { $0.last!.isFaceUp && $0.dropLast().allSatisfy { !$0.isFaceUp } })
        #expect(state.stock.count == 24)
        let all = state.stock + state.tableau.flatMap { $0.map(\.card) }
        #expect(Set(all).count == 52)
    }

    /// Golden value: if this changes, every device would deal different daily games.
    @Test func dealIsStable() {
        let state = GameState.deal(seed: 0)
        #expect(state.tableau.map { $0.last!.card.description } == GameState.deal(seed: 0).tableau.map { $0.last!.card.description })
        #expect(state.tableau.map { $0.last!.card.description }.joined(separator: " ") == "8♣ 10♠ 8♠ 3♦ 4♣ 8♦ A♥")
    }

    @Test func tableauNeedsAlternateColorsOneLower() {
        let state = table(column("8♠"), column("7♥"), column("7♣"), column("9♦"))
        #expect(state.accepts([card("7♥")], at: .tableau(0)))
        #expect(!state.accepts([card("7♣")], at: .tableau(0)))
        #expect(!state.accepts([card("9♦")], at: .tableau(0)))
    }

    @Test func onlyKingsGoOnEmptyColumns() {
        let state = table(column("8♠"))
        #expect(state.accepts([card("K♥")], at: .tableau(3)))
        #expect(!state.accepts([card("Q♥")], at: .tableau(3)))
    }

    @Test func foundationsGoUpBySuitFromAce() {
        let state = table(foundations: [2, 0, 0, 0], column("8♠"))
        #expect(state.accepts([card("3♠")], at: .foundation(.spades)))
        #expect(!state.accepts([card("4♠")], at: .foundation(.spades)))
        #expect(!state.accepts([card("3♣")], at: .foundation(.spades)))
        #expect(state.accepts([card("A♥")], at: .foundation(.hearts)))
    }

    @Test func movingARunTurnsOverTheCardBelow() {
        var state = table(column("?2♦", "9♥", "8♠", "7♦"), column("10♣"))
        #expect(state.runLength(column: 0, from: 1) == 3)
        let move = Move.move(from: .tableau(0), count: 3, to: .tableau(1))
        #expect(state.isLegal(move))
        let outcome = state.apply(move)
        #expect(outcome.flipped)
        #expect(state.tableau[0] == column("2♦"))
        #expect(state.tableau[1].map(\.card) == ["10♣", "9♥", "8♠", "7♦"].map(card))
    }

    @Test func brokenRunsDontMove() {
        let state = table(column("9♥", "8♥"), column("10♣"))
        #expect(state.runLength(column: 0, from: 0) == nil)
        #expect(!state.isLegal(.move(from: .tableau(0), count: 2, to: .tableau(1))))
    }

    @Test func drawingAndRecycling() {
        var state = table(stock: ["2♠", "3♠"], column("K♠"))
        state.apply(.draw)
        state.apply(.draw)
        #expect(state.waste.map(\.description) == ["3♠", "2♠"])
        #expect(state.stock.isEmpty)
        let outcome = state.apply(.draw)
        #expect(outcome.recycled)
        #expect(state.waste.isEmpty)
        // Same order as before: the first card drawn comes up first again.
        state.apply(.draw)
        #expect(state.waste.last == card("3♠"))
    }

    @Test func tapPrefersFoundationThenNonEmptyColumn() {
        let state = table(foundations: [1, 0, 0, 0], column("2♠"), column("3♥"), column())
        #expect(state.bestDestination(from: .tableau(0)) == .foundation(.spades))
        let other = table(column("Q♦", "J♠"), column("Q♥"), column())
        #expect(other.bestDestination(from: .tableau(0)) == .tableau(1))
        // A king already at the bottom of its column stays.
        let king = table(column("K♠"), column())
        #expect(king.bestDestination(from: .tableau(0)) == nil)
    }

    @Test func autoCompleteWhenEverythingIsFaceUp() {
        let state = table(foundations: [12, 12, 12, 11], column("K♣", "Q♣"), column("K♠"), column("K♥"), column("K♦"))
        #expect(state.canAutoComplete)
        #expect(state.autoCompleteMove == .move(from: .tableau(0), count: 1, to: .foundation(.clubs)))
        let blocked = table(foundations: [12, 12, 12, 11], column("?K♣", "Q♣"), column("K♠"), column("K♥"), column("K♦"))
        #expect(!blocked.canAutoComplete)
    }
}

@Suite struct SessionTests {
    @Test func scoresFlipsWasteAndFoundations() {
        var session = GameSession(state: table(waste: ["7♥"], column("?A♠", "8♠"), column("?2♣", "6♣")))
        session.play(.move(from: .waste, count: 1, to: .tableau(0)))
        #expect(session.score == 5)
        session.play(.move(from: .tableau(1), count: 1, to: .tableau(0)))
        #expect(session.score == 10) // the 2♣ turned over
        #expect(session.moves == 2)
    }

    @Test func undoTakesBackPointsButNotHintCosts() {
        var session = GameSession(state: table(waste: ["7♥"], column("8♠"), column("K♦")))
        _ = session.chargeHint()
        #expect(session.score == -10)
        session.play(.move(from: .waste, count: 1, to: .tableau(0)))
        #expect(session.score == -5)
        session.undo()
        #expect(session.score == -10)
        #expect(session.state.waste == [card("7♥")])
        #expect(session.usedUndo)
        #expect(session.moves == 2)
    }

    @Test func illegalMovesAreIgnored() {
        var session = GameSession(state: table(column("8♠"), column("7♣")))
        #expect(session.play(.move(from: .tableau(1), count: 1, to: .tableau(0))) == nil)
        #expect(session.moves == 0)
    }

    @Test func winningAddsTheMoveBonus() throws {
        var session = GameSession(state: table(foundations: [13, 13, 13, 12], column("K♣")))
        let played = session.play(.move(from: .tableau(0), count: 1, to: .foundation(.clubs)))
        let events = try #require(played)
        #expect(session.isWon)
        // Won at 0 seconds: ×2 on play points and the bonus.
        #expect(session.timeMultiplierTenths == 20)
        #expect(session.score == (10 + 500) * 2)
        #expect(events.contains { if case .won = $0 { true } else { false } })
    }

    @Test func bonusShrinksAfterAHundredMoves() {
        #expect(Scoring.standard.bonus(forMoves: 98) == 500)
        #expect(Scoring.standard.bonus(forMoves: 150) == 400)
        #expect(Scoring.standard.bonus(forMoves: 400) == 0)
    }

    @Test func timeMultiplierGoesFromTwoToOne() {
        let scoring = Scoring.standard
        #expect(scoring.timeMultiplierTenths(forSeconds: 0) == 20)
        #expect(scoring.timeMultiplierTenths(forSeconds: 180) == 20)
        #expect(scoring.timeMultiplierTenths(forSeconds: 316) == 18)
        #expect(scoring.timeMultiplierTenths(forSeconds: 540) == 15)
        #expect(scoring.timeMultiplierTenths(forSeconds: 900) == 10)
        #expect(scoring.timeMultiplierTenths(forSeconds: 5_000) == 10)
    }

    /// Hint costs stay outside the multiplier.
    @Test func hintsArentMultiplied() throws {
        var session = GameSession(state: table(foundations: [13, 13, 13, 12], column("K♣")))
        _ = session.chargeHint()
        session.play(.move(from: .tableau(0), count: 1, to: .foundation(.clubs)))
        #expect(session.score == (10 + 500) * 2 - 10)
    }

    @Test func ladderIsReported() throws {
        let run = ["Q♥", "J♠", "10♥", "9♠", "8♥", "7♠", "6♥", "5♠", "4♥", "3♠", "2♥"]
        var session = GameSession(state: table(waste: ["A♠"], [TableauCard(card("K♠"), faceUp: true)] + run.map { TableauCard(card($0), faceUp: true) }))
        let played = session.play(.move(from: .waste, count: 1, to: .tableau(0)))
        let events = try #require(played)
        #expect(events.contains(.ladder))
    }

    @Test func clockRunsOnlyWhilePlaying() {
        var session = GameSession(state: table(stock: ["2♠"], column("K♠")))
        session.tick()
        #expect(session.elapsedSeconds == 0)
        session.play(.draw)
        session.tick()
        session.tick()
        #expect(session.elapsedSeconds == 2)
    }

    /// Games saved before the clock existed still load, at 0 seconds.
    @Test func oldSavedGamesLoad() throws {
        let session = GameSession(seed: 3)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as! [String: Any]
        json.removeValue(forKey: "elapsed")
        let old = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.elapsedSeconds == 0)
    }

    @Test func savedGamesRoundTrip() throws {
        var session = GameSession(mode: .daily(dayKey: "2026-10-27"), seed: 9)
        session.play(.draw)
        let data = try JSONEncoder().encode(session)
        #expect(try JSONDecoder().decode(GameSession.self, from: data) == session)
    }
}

@Suite struct DailyTests {
    @Test func sameDaySameDeal() {
        #expect(Deals.dailySeed(forDayKey: "2026-10-27") == Deals.dailySeed(forDayKey: "2026-10-27"))
        #expect(Deals.dailySeed(forDayKey: "2026-10-27") != Deals.dailySeed(forDayKey: "2026-10-28"))
    }

    /// Every daily deal is winnable and, almost always, matches its weekday's difficulty.
    @Test func dailyDealsAreWinnable() {
        var matched = 0
        var day: String? = "2026-11-02"
        for _ in 0..<28 {
            let key = day!
            let seed = Deals.dailySeed(forDayKey: key)
            guard case .solved(_, let effort) = Solver.solve(.deal(seed: seed), budget: Deals.budget) else {
                Issue.record("\(key) isn't winnable")
                continue
            }
            if Difficulty(effort: effort) == Deals.dailyDifficulty(forDayKey: key) { matched += 1 }
            day = DailyKey.dayKey(key, addingDays: 1)
        }
        #expect(matched >= 26)
    }

    /// Following hints wins: a draw hint leads to the card the solver wants, instead of a
    /// new target after every draw.
    @Test func followingHintsWins() throws {
        var session = GameSession(seed: Deals.winnableSeed(startingAt: 42))
        while !session.isWon, session.moves < 600, let move = GameSession.suggestion(for: session.state) {
            session.play(move)
        }
        #expect(session.isWon, "after \(session.moves) moves")
    }

    @Test func hintFollowsTheSolver() throws {
        let state = GameState.deal(seed: Deals.dailySeed(forDayKey: "2026-11-02"))
        let move = try #require(GameSession.suggestion(for: state))
        #expect(state.isLegal(move))
    }
}

@Suite struct ProgressTests {
    private func win(moves: Int = 120, undo: Bool = false, hints: Int = 0, recycles: Int = 1) -> ProgressEvent {
        .won(WinSummary(score: 900, moves: moves, usedUndo: undo, hintsUsed: hints, recycles: recycles, seconds: 300), isClassic: true)
    }

    @Test func firstCleanWinUnlocksSeveral() {
        var progress = PlayerProgress()
        let unlocked = Set(progress.record(win(moves: 90, recycles: 0)))
        #expect(unlocked == [.firstWin, .noUndo, .noHints, .onePass, .economy])
        #expect(progress.bestScore == 900)
    }

    @Test func countedWins() {
        var progress = PlayerProgress()
        for _ in 0..<9 { _ = progress.record(win(undo: true, hints: 1)) }
        #expect(!progress.unlocked.contains(.tenWins))
        #expect(progress.record(win(undo: true, hints: 1)) == [.tenWins])
        #expect(progress.progress(of: .fiftyWins) == 0.2)
    }

    @Test func inTheRedAndNightOwl() {
        var progress = PlayerProgress()
        #expect(progress.record(.hintCharged(scoreAfter: 0)).isEmpty)
        #expect(progress.record(.hintCharged(scoreAfter: -3)) == [.inTheRed])
        #expect(Set(progress.record(.dailyCompleted(currentStreak: 7, localHour: 2))) == [.consistency, .nightOwl])
    }

    @Test func mergeKeepsTheMost() {
        var a = PlayerProgress(), b = PlayerProgress()
        _ = a.record(win())
        _ = b.record(.abandoned(played: true))
        _ = b.record(.abandoned(played: true))
        let merged = a.merged(with: b)
        #expect(merged.gamesWon == 1 && merged.gamesPlayed == 2 && merged.unlocked.contains(.firstWin))
    }
}

@Suite struct SolverTests {
    /// Both searches call a lost position unsolvable and a won-in-one position solved.
    @Test func verdictsAgreeOnSimplePositions() {
        // Spades are done but the A♥ is buried under the 2♥ it needs to go after: lost.
        let lost = table(foundations: [13, 0, 13, 13], column("?A♥", "2♥"), column("?3♥", "4♥"))
        #expect(Solver.solve(lost) == .unsolvable)
        #expect(Solver.solve(lost, complete: true) == .unsolvable)
        let won = table(foundations: [13, 13, 13, 12], column("K♣"))
        if case .solved = Solver.solve(won) {} else { Issue.record("should be solved") }
        if case .solved = Solver.solve(won, complete: true) {} else { Issue.record("should be solved") }
    }
}

@Suite struct RegressionTests {
    /// A game from the device (2026-10-27) that looked stuck but got no notice: the
    /// depth-first search ran out of budget (3 million positions) without a verdict. The
    /// best-first search runs out of moves and calls it lost.
    @Test func stuckGameFromDeviceIsFlagged() {
        let state = table(
            waste: ["Q♣", "Q♦", "7♦", "3♦", "6♦", "K♠", "J♥", "K♦", "K♥"],
            foundations: [2, 1, 0, 3],
            column("K♣", "Q♥", "J♠", "10♥", "9♠", "8♥", "7♠", "6♥", "5♠", "4♦"),
            column("J♦", "10♣", "9♦"),
            column("?Q♠", "?A♦", "3♥"),
            column("?5♣", "?10♠", "2♦"),
            column("?J♣", "?8♠", "?2♥", "?4♠", "9♥", "8♣", "7♥", "6♠", "5♥"),
            column("?3♠", "?9♣", "?4♣", "8♦"),
            column("?4♥", "?10♦", "?5♦", "?7♣", "6♣")
        )
        #expect(Solver.solve(state, budget: 40_000) == .unsolvable)
    }
}
