import QuietCore

/// Where cards can be taken from or put on.
public enum Location: Hashable, Codable, Sendable {
    case waste
    case foundation(Suit)
    case tableau(Int)
}

/// One player action. A tap on the stock is `.draw` (or a recycle when the stock is empty).
public enum Move: Hashable, Codable, Sendable {
    case draw
    /// `count` cards from the end of `from` (more than one only between tableau columns).
    case move(from: Location, count: Int, to: Location)
}

/// The table: Klondike, draw one, unlimited passes through the stock.
public struct GameState: Hashable, Codable, Sendable {
    /// Face down; the top is the last card.
    public internal(set) var stock: [Card]
    /// Face up; the top (playable) card is the last.
    public internal(set) var waste: [Card]
    /// One per suit, in `Suit` order, ace first.
    public internal(set) var foundations: [[Card]]
    /// Seven columns, the playable card last.
    public internal(set) var tableau: [[TableauCard]]

    public init(stock: [Card], waste: [Card] = [], foundations: [[Card]] = Array(repeating: [], count: 4), tableau: [[TableauCard]]) {
        self.stock = stock
        self.waste = waste
        self.foundations = foundations
        self.tableau = tableau
    }

    /// Shuffles with our own PRNG (Fisher–Yates; never `shuffled()`, whose output may change
    /// between OS versions) and deals: column n gets n cards, only the last one face up,
    /// dealt row by row like at a table. The other 24 make the stock.
    public static func deal(seed: UInt64) -> GameState {
        var random = SeededRandom(seed: seed)
        var cards = Card.deck
        for i in stride(from: cards.count - 1, to: 0, by: -1) {
            cards.swapAt(i, random.nextInt(in: 0...i))
        }
        var tableau: [[TableauCard]] = Array(repeating: [], count: 7)
        var next = 0
        for row in 0..<7 {
            for column in row..<7 {
                tableau[column].append(TableauCard(cards[next], faceUp: row == column))
                next += 1
            }
        }
        return GameState(stock: Array(cards[next...]), tableau: tableau)
    }

    // MARK: Reading

    public var isWon: Bool { foundations.allSatisfy { $0.count == 13 } }

    public func foundation(_ suit: Suit) -> [Card] { foundations[suit.rawValue] }

    /// The card that would be taken from `location` (the top one).
    public func topCard(at location: Location) -> Card? {
        switch location {
        case .waste: waste.last
        case .foundation(let suit): foundations[suit.rawValue].last
        case .tableau(let column): tableau[column].last.flatMap { $0.isFaceUp ? $0.card : nil }
        }
    }

    /// Number of face-up cards from `index` to the end of the column, if they form a run
    /// that can move together (each one stacks on the one before).
    public func runLength(column: Int, from index: Int) -> Int? {
        let cards = tableau[column]
        guard cards.indices.contains(index), cards[index].isFaceUp else { return nil }
        for i in (index + 1)..<cards.count where !cards[i].card.stacks(on: cards[i - 1].card) {
            return nil
        }
        return cards.count - index
    }

    /// All face up, nothing left to draw: the rest can be played to the foundations.
    public var canAutoComplete: Bool {
        stock.isEmpty && waste.isEmpty && tableau.allSatisfy { $0.allSatisfy(\.isFaceUp) } && !isWon
    }

    // MARK: Rules

    /// Whether `cards` (bottom first) can be put on `destination`.
    public func accepts(_ cards: [Card], at destination: Location) -> Bool {
        guard let first = cards.first else { return false }
        switch destination {
        case .waste:
            return false
        case .foundation(let suit):
            guard cards.count == 1, first.suit == suit else { return false }
            return first.rank == foundations[suit.rawValue].count + 1
        case .tableau(let column):
            guard let top = tableau[column].last else { return first.rank == 13 }
            return top.isFaceUp && first.stacks(on: top.card)
        }
    }

    /// The cards a move would take, or nil if the source can't give them.
    func cards(for move: Move) -> [Card]? {
        guard case .move(let from, let count, _) = move, count > 0 else { return nil }
        switch from {
        case .waste:
            return count == 1 ? waste.last.map { [$0] } : nil
        case .foundation(let suit):
            return count == 1 ? foundations[suit.rawValue].last.map { [$0] } : nil
        case .tableau(let column):
            let start = tableau[column].count - count
            guard start >= 0, runLength(column: column, from: start) == count else { return nil }
            return tableau[column][start...].map(\.card)
        }
    }

    public func isLegal(_ move: Move) -> Bool {
        switch move {
        case .draw:
            return !stock.isEmpty || !waste.isEmpty
        case .move(let from, _, let to):
            guard from != to, let cards = cards(for: move) else { return false }
            return accepts(cards, at: to)
        }
    }

    /// What applying a move did, for scoring and feedback.
    public struct Outcome: Hashable, Sendable {
        public var recycled = false
        /// A face-down card turned over in the source column.
        public var flipped = false
    }

    /// Applies a legal move. Turns over the card it uncovers in the tableau.
    @discardableResult
    public mutating func apply(_ move: Move) -> Outcome {
        var outcome = Outcome()
        switch move {
        case .draw:
            if let card = stock.popLast() {
                waste.append(card)
            } else {
                stock = waste.reversed()
                waste = []
                outcome.recycled = true
            }
        case .move(let from, let count, let to):
            guard let cards = cards(for: move) else { return outcome }
            switch from {
            case .waste: waste.removeLast()
            case .foundation(let suit): foundations[suit.rawValue].removeLast()
            case .tableau(let column):
                tableau[column].removeLast(count)
                if let last = tableau[column].indices.last, !tableau[column][last].isFaceUp {
                    tableau[column][last].isFaceUp = true
                    outcome.flipped = true
                }
            }
            switch to {
            case .waste: break
            case .foundation(let suit): foundations[suit.rawValue].append(contentsOf: cards)
            case .tableau(let column): tableau[column].append(contentsOf: cards.map { TableauCard($0, faceUp: true) })
            }
        }
        return outcome
    }

    // MARK: Choosing moves

    /// Where a tap sends the card at `location` (with `count` cards on it in the tableau):
    /// the foundation first, then a column that already has cards, then an empty column
    /// (only for a king that isn't already at the bottom of its own column).
    public func bestDestination(from location: Location, count: Int = 1) -> Location? {
        let move = Move.move(from: location, count: count, to: .waste)
        guard let cards = cards(for: move), let first = cards.first else { return nil }
        if count == 1, accepts(cards, at: .foundation(first.suit)), location != .foundation(first.suit) {
            return .foundation(first.suit)
        }
        let columns = (0..<7).filter { .tableau($0) != location && accepts(cards, at: .tableau($0)) }
        if let column = columns.first(where: { !tableau[$0].isEmpty }) { return .tableau(column) }
        if let empty = columns.first {
            if case .tableau(let source) = location, tableau[source].count == count { return nil }
            return .tableau(empty)
        }
        return nil
    }

    /// Every legal move except pointless ones (a whole column to an empty column).
    public var legalMoves: [Move] {
        var moves: [Move] = []
        var sources: [(Location, Int)] = []
        if !waste.isEmpty { sources.append((.waste, 1)) }
        for suit in Suit.allCases where !foundations[suit.rawValue].isEmpty { sources.append((.foundation(suit), 1)) }
        for column in 0..<7 {
            for index in tableau[column].indices {
                if let length = runLength(column: column, from: index) { sources.append((.tableau(column), length)) }
            }
        }
        for (from, count) in sources {
            var destinations: [Location] = Suit.allCases.map { .foundation($0) } + (0..<7).map { .tableau($0) }
            destinations.removeAll { $0 == from }
            for to in destinations {
                let move = Move.move(from: from, count: count, to: to)
                guard isLegal(move) else { continue }
                if case .tableau(let source) = from, case .tableau(let target) = to,
                   tableau[target].isEmpty, tableau[source].count == count { continue }
                moves.append(move)
            }
        }
        return moves
    }

    /// The next card to play when auto-completing: the lowest rank that fits a foundation.
    public var autoCompleteMove: Move? {
        var best: (Move, Int)?
        let sources: [Location] = [.waste] + (0..<7).map { .tableau($0) }
        for source in sources {
            guard let card = topCard(at: source), accepts([card], at: .foundation(card.suit)) else { continue }
            if best == nil || card.rank < best!.1 {
                best = (.move(from: source, count: 1, to: .foundation(card.suit)), card.rank)
            }
        }
        return best?.0
    }
}
