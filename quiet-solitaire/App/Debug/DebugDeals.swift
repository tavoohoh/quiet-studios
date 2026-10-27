#if DEBUG
import QuietSolitaireCore

/// Fixed tables for QA and UI tests.
enum DebugDeals {
    /// Everything face up, one card from the waste away from auto-complete.
    static var nearlyWon: GameState {
        let suits = Suit.allCases
        var tableau: [[TableauCard]] = Array(repeating: [], count: 7)
        // Four columns K → 10 alternating colors; the rest of the cards on the foundations.
        let runs: [[Card]] = [
            [Card(13, .spades), Card(12, .hearts), Card(11, .clubs), Card(10, .diamonds)],
            [Card(13, .hearts), Card(12, .clubs), Card(11, .diamonds), Card(10, .spades)],
            [Card(13, .diamonds), Card(12, .spades), Card(11, .hearts), Card(10, .clubs)],
            [Card(13, .clubs), Card(12, .diamonds), Card(11, .spades)],
        ]
        for (i, run) in runs.enumerated() { tableau[i] = run.map { TableauCard($0, faceUp: true) } }
        let foundations = suits.map { suit in (1...9).map { Card($0, suit) } }
        return GameState(stock: [], waste: [Card(10, .hearts)], foundations: foundations, tableau: tableau)
    }

    /// Lost: the A♥ is buried under the 2♥ and 3♥ it has to come before.
    static var lost: GameState {
        let foundations = Suit.allCases.map { suit in suit == .hearts ? [] : (1...13).map { Card($0, suit) } }
        var tableau: [[TableauCard]] = Array(repeating: [], count: 7)
        tableau[0] = [TableauCard(Card(1, .hearts), faceUp: false), TableauCard(Card(2, .hearts), faceUp: true)]
        tableau[1] = [TableauCard(Card(3, .hearts), faceUp: false), TableauCard(Card(4, .hearts), faceUp: true)]
        tableau[2] = (5...13).reversed().map { TableauCard(Card($0, .hearts), faceUp: false) } + []
        tableau[2][tableau[2].count - 1].isFaceUp = true
        return GameState(stock: [], foundations: foundations, tableau: tableau)
    }
}
#endif
