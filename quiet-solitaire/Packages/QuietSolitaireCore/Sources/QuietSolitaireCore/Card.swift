/// Suits in the order of the foundations on screen: ♠ ♥ ♦ ♣.
public enum Suit: Int, CaseIterable, Codable, Sendable {
    case spades, hearts, diamonds, clubs

    public var isRed: Bool { self == .hearts || self == .diamonds }
}

/// A playing card. Rank 1 is the ace, 11–13 jack, queen, king.
public struct Card: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rank: Int
    public let suit: Suit

    public init(_ rank: Int, _ suit: Suit) {
        precondition((1...13).contains(rank))
        self.rank = rank
        self.suit = suit
    }

    /// 0..<52, stable: suit-major.
    public var id: Int { suit.rawValue * 13 + rank - 1 }

    public init(id: Int) {
        self.init(id % 13 + 1, Suit(rawValue: id / 13)!)
    }

    public var isRed: Bool { suit.isRed }

    /// Goes on `other` in the tableau: one rank lower, other color.
    public func stacks(on other: Card) -> Bool {
        rank == other.rank - 1 && isRed != other.isRed
    }

    public var description: String {
        let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
        return ranks[rank - 1] + ["♠", "♥", "♦", "♣"][suit.rawValue]
    }

    /// The 52 cards in a fixed order, before shuffling.
    public static let deck: [Card] = (0..<52).map(Card.init(id:))
}

/// A card in a tableau column.
public struct TableauCard: Hashable, Codable, Sendable {
    public let card: Card
    public var isFaceUp: Bool

    public init(_ card: Card, faceUp: Bool) {
        self.card = card
        isFaceUp = faceUp
    }
}
