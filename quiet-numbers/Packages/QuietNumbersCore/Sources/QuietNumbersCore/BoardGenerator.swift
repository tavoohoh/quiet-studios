public enum BoardGenerator {
    public static let initialCount = 42
    public static let minimumPairs = 3

    /// A fresh board of `initialCount` numbers (1–9) with at least `minimumPairs` valid pairs,
    /// where every number could in principle find a partner (see `isPairable`).
    /// Invalid candidates are discarded and the generator keeps advancing, so the result
    /// stays deterministic for a given generator state.
    public static func makeBoard(using random: inout SeededRandom) -> Board {
        while true {
            let values = (0..<initialCount).map { _ in random.nextInt(in: 1...9) }
            guard isPairable(values) else { continue }
            let board = Board(values: values)
            if MatchRules.validPairs(on: board).count >= minimumPairs {
                return board
            }
        }
    }

    /// Numbers only ever pair within their family ({1, 9}, {2, 8}, {3, 7}, {4, 6}, {5}),
    /// so the board can only be cleared without + if every family has an even count.
    /// Necessary, not sufficient: positions can still leave a number stranded.
    public static func isPairable(_ values: [Int]) -> Bool {
        var odd = Set<Int>()
        for value in values {
            let family = min(value, 10 - value)
            if odd.remove(family) == nil { odd.insert(family) }
        }
        return odd.isEmpty
    }
}
