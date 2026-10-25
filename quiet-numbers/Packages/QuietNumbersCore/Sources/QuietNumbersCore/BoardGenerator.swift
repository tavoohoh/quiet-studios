public enum BoardGenerator {
    public static let initialCount = 27
    public static let minimumPairs = 3

    /// A fresh board of `initialCount` numbers (1–9) with at least `minimumPairs` valid pairs.
    /// Invalid candidates are discarded and the generator keeps advancing, so the result
    /// stays deterministic for a given generator state.
    public static func makeBoard(using random: inout SeededRandom) -> Board {
        while true {
            let values = (0..<initialCount).map { _ in random.nextInt(in: 1...9) }
            let board = Board(values: values)
            if MatchRules.validPairs(on: board).count >= minimumPairs {
                return board
            }
        }
    }
}
