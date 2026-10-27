import QuietCore

/// Klondike solver (draw one, unlimited passes).
///
/// With draw one and unlimited passes every card in the stock and waste can be reached
/// by drawing, so they're searched as one "talon" set: taking any of its cards is one
/// abstract move. Safe cards go to the foundations automatically and positions already
/// seen are skipped. The search is best-first (`BestFirstSearch`): it always expands the
/// most promising position, so one huge bad branch can't eat the budget (a depth-first
/// search did, and missed wins the player could see; changed 2026-10-27). It stops after
/// `budget` positions, counted (not timed), so the answer is the same on every device:
/// that's what lets the daily deal check itself on device.
public enum Solver {
    public enum Result: Equatable, Sendable {
        /// Solvable. `firstMove` is the first real move to make (`.draw` when the card to
        /// play is still in the stock); `effort` is how many positions the search visited.
        case solved(firstMove: Move?, effort: Int)
        /// Searched everything reachable: no way to win from here.
        case unsolvable
        /// Gave up at the budget.
        case unknown
    }

    /// `complete`: also split runs anywhere. The quick search skips those splits unless
    /// they free a card for the foundations, so its "unsolvable" isn't a strict proof;
    /// measured (2026-10-27) on 1,346 positions from played games, the 112 it called lost
    /// were never won by the complete search (108 proven lost, 4 undecided).
    public static func solve(_ state: GameState, budget: Int = 60_000, complete: Bool = false) -> Result {
        var search = BestFirstSearch(budget: budget, complete: complete)
        let start = Position(state)
        guard let path = search.run(start) else {
            return search.exhausted ? .unknown : .unsolvable
        }
        return .solved(firstMove: path.first.map { start.concrete($0, in: state) }, effort: search.expanded)
    }
}

/// Abstract moves in a position.
enum Step: Hashable {
    case tableauToFoundation(column: Int)
    case talonToFoundation(card: Int)
    case talonToTableau(card: Int, column: Int)
    /// Face-up cards of `column` from `index` (into the up part) onto `to`.
    case tableauToTableau(column: Int, index: Int, to: Int)
    case foundationToTableau(suit: Int, column: Int)
}

/// Compact position: card ids, foundations as counts.
struct Position {
    var foundations: [Int]
    var talon: [Int]
    var down: [[Int]]
    var up: [[Int]]

    init(_ state: GameState) {
        foundations = state.foundations.map(\.count)
        // Stock order then waste: deterministic, and order doesn't matter for reachability.
        talon = state.stock.map(\.id) + state.waste.map(\.id)
        down = state.tableau.map { $0.filter { !$0.isFaceUp }.map(\.card.id) }
        up = state.tableau.map { $0.filter(\.isFaceUp).map(\.card.id) }
    }

    static func rank(_ id: Int) -> Int { id % 13 + 1 }
    static func suit(_ id: Int) -> Int { id / 13 }
    static func isRed(_ id: Int) -> Bool { suit(id) == 1 || suit(id) == 2 }
    static func stacks(_ a: Int, on b: Int) -> Bool { rank(a) == rank(b) - 1 && isRed(a) != isRed(b) }

    var isWon: Bool { foundations.allSatisfy { $0 == 13 } }

    func fitsFoundation(_ id: Int) -> Bool { foundations[Self.suit(id)] == Self.rank(id) - 1 }

    func fitsTableau(_ id: Int, column: Int) -> Bool {
        guard let top = up[column].last else { return down[column].isEmpty && Self.rank(id) == 13 }
        return Self.stacks(id, on: top)
    }

    /// No later move can need this card in the tableau: both foundations of the other
    /// color are already past the rank below it.
    func isSafeForFoundation(_ id: Int) -> Bool {
        let rank = Self.rank(id)
        if rank <= 2 { return true }
        let others = Self.isRed(id) ? [0, 3] : [1, 2]
        return others.allSatisfy { foundations[$0] >= rank - 1 }
    }

    mutating func flip(_ column: Int) {
        if up[column].isEmpty, let card = down[column].popLast() { up[column].append(card) }
    }

    /// Plays safe cards to the foundations until none is left.
    mutating func playSafeCards() {
        var changed = true
        while changed {
            changed = false
            for column in 0..<7 {
                if let card = up[column].last, fitsFoundation(card), isSafeForFoundation(card) {
                    up[column].removeLast()
                    foundations[Self.suit(card)] += 1
                    flip(column)
                    changed = true
                }
            }
            if let index = talon.firstIndex(where: { fitsFoundation($0) && isSafeForFoundation($0) }) {
                foundations[Self.suit(talon.remove(at: index))] += 1
                changed = true
            }
        }
    }

    /// Candidate steps, most promising first.
    func steps(complete: Bool = false) -> [Step] {
        var reveal: [(Step, Int)] = [], toFoundation: [Step] = [], fromTalon: [Step] = [], other: [Step] = []
        let firstEmpty = (0..<7).first { up[$0].isEmpty && down[$0].isEmpty }
        for column in 0..<7 {
            if let card = up[column].last, fitsFoundation(card) { toFoundation.append(.tableauToFoundation(column: column)) }
        }
        for card in talon where fitsFoundation(card) { toFoundation.append(.talonToFoundation(card: card)) }
        for column in 0..<7 {
            for index in up[column].indices {
                let card = up[column][index]
                for target in 0..<7 where target != column && fitsTableau(card, column: target) {
                    let targetIsEmpty = up[target].isEmpty && down[target].isEmpty
                    if targetIsEmpty && target != firstEmpty { continue }
                    if index == 0 {
                        // Moving a king that already sits on an empty spot is pointless.
                        if down[column].isEmpty && targetIsEmpty { continue }
                        reveal.append((.tableauToTableau(column: column, index: index, to: target), down[column].count))
                    } else if complete || fitsFoundation(up[column][index - 1]) {
                        // Splitting a run only helps if it frees the card under it.
                        other.append(.tableauToTableau(column: column, index: index, to: target))
                    }
                }
            }
        }
        for card in talon {
            for target in 0..<7 where fitsTableau(card, column: target) {
                if up[target].isEmpty && target != firstEmpty { continue }
                fromTalon.append(.talonToTableau(card: card, column: target))
            }
        }
        for suit in 0..<4 where foundations[suit] > 0 {
            let card = suit * 13 + foundations[suit] - 1
            for target in 0..<7 where !up[target].isEmpty && fitsTableau(card, column: target) {
                other.append(.foundationToTableau(suit: suit, column: target))
            }
        }
        let revealing = reveal.sorted { $0.1 > $1.1 }.map(\.0)
        return toFoundation + revealing + fromTalon + other
    }

    func applying(_ step: Step) -> Position {
        var next = self
        switch step {
        case .tableauToFoundation(let column):
            let card = next.up[column].removeLast()
            next.foundations[Self.suit(card)] += 1
            next.flip(column)
        case .talonToFoundation(let card):
            next.talon.removeAll { $0 == card }
            next.foundations[Self.suit(card)] += 1
        case .talonToTableau(let card, let column):
            next.talon.removeAll { $0 == card }
            next.up[column].append(card)
        case .tableauToTableau(let column, let index, let target):
            next.up[target] += next.up[column][index...]
            next.up[column].removeSubrange(index...)
            next.flip(column)
        case .foundationToTableau(let suit, let column):
            next.foundations[suit] -= 1
            next.up[column].append(suit * 13 + next.foundations[suit])
        }
        next.playSafeCards()
        return next
    }

    /// Hash of the position, independent of column order and talon order. FNV-1a, so it's
    /// the same on every device (unlike `Hasher`).
    var key: UInt64 {
        var columns: [[UInt8]] = []
        for column in 0..<7 {
            var bytes: [UInt8] = [UInt8(down[column].count)]
            bytes += down[column].map { UInt8($0) }
            bytes.append(0xFE)
            bytes += up[column].map { UInt8($0) }
            bytes.append(0xFD)
            columns.append(bytes)
        }
        columns.sort { $0.lexicographicallyPrecedes($1) }
        var bytes: [UInt8] = foundations.map { UInt8($0) }
        bytes += talon.sorted().map { UInt8($0) }
        bytes.append(0xFF)
        for column in columns { bytes += column }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// The real move for the first abstract step, in the state the position came from.
    func concrete(_ step: Step, in state: GameState) -> Move {
        func talonMove(_ card: Int, to destination: Location) -> Move {
            state.waste.last?.id == card ? .move(from: .waste, count: 1, to: destination) : .draw
        }
        switch step {
        case .tableauToFoundation(let column):
            let card = up[column].last!
            return .move(from: .tableau(column), count: 1, to: .foundation(Suit(rawValue: Self.suit(card))!))
        case .talonToFoundation(let card):
            return talonMove(card, to: .foundation(Suit(rawValue: Self.suit(card))!))
        case .talonToTableau(let card, let column):
            return talonMove(card, to: .tableau(column))
        case .tableauToTableau(let column, let index, let target):
            return .move(from: .tableau(column), count: up[column].count - index, to: .tableau(target))
        case .foundationToTableau(let suit, let column):
            return .move(from: .foundation(Suit(rawValue: suit)!), count: 1, to: .tableau(column))
        }
    }
}
