/// The tutorial's hand-made table: each move sets up the next, and a tap on the card to
/// move sends it exactly where the step says (`TutorialTests` plays it through).
public enum Tutorial {
    public static var table: GameState {
        func up(_ rank: Int, _ suit: Suit) -> TableauCard { TableauCard(Card(rank, suit), faceUp: true) }
        func down(_ rank: Int, _ suit: Suit) -> TableauCard { TableauCard(Card(rank, suit), faceUp: false) }
        return GameState(
            stock: [Card(3, .clubs), Card(11, .diamonds), Card(7, .hearts)],
            tableau: [
                [down(2, .diamonds), up(8, .spades)],
                [down(9, .hearts), up(1, .diamonds)],
                [down(5, .spades), down(4, .clubs), up(6, .clubs)],
                [down(4, .hearts), up(13, .clubs)],
                [down(10, .spades), down(2, .clubs), down(3, .hearts), up(12, .diamonds)],
                [down(6, .diamonds), up(11, .spades)],
                [down(5, .hearts), down(9, .clubs), up(10, .hearts)],
            ]
        )
    }

    /// One move per step, in order.
    public static let moves: [Move] = [
        // Turn a card: the 7♥.
        .draw,
        // Red on black, one lower: the 7♥ on the 8♠.
        .move(from: .waste, count: 1, to: .tableau(0)),
        // Aces start the foundations; the 9♥ under it turns over.
        .move(from: .tableau(1), count: 1, to: .foundation(.diamonds)),
        // A whole run moves together: 8♠ 7♥ onto the 9♥; the 2♦ turns over.
        .move(from: .tableau(0), count: 2, to: .tableau(1)),
        // The foundation goes on up: the 2♦ on the A♦, leaving the column empty.
        .move(from: .tableau(0), count: 1, to: .foundation(.diamonds)),
        // Only a king goes on an empty column.
        .move(from: .tableau(3), count: 1, to: .tableau(0)),
    ]
}
