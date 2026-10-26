public enum BoardGenerator {
    /// Stage 1 (and every daily challenge).
    public static let initialCount = initialCount(forStage: 1)
    public static let minimumPairs = minimumPairs(forStage: 1)

    /// Difficulty grows with the stage: bigger boards (42 → 54 numbers by stage 5)…
    /// Always even: `isPairable` needs every family to have an even count.
    public static func initialCount(forStage stage: Int) -> Int {
        [42, 44, 48, 50, 54][min(max(stage, 1), 5) - 1]
    }

    /// …and fewer easy pairs to start with (3, then 2 from stage 3, then 1 from stage 5).
    public static func minimumPairs(forStage stage: Int) -> Int {
        switch stage {
        case ...2: 3
        case 3...4: 2
        default: 1
        }
    }

    /// A fresh board for `stage`, with at least its minimum of valid pairs, where every
    /// number could in principle find a partner (see `isPairable`).
    /// Invalid candidates are discarded and the generator keeps advancing, so the result
    /// stays deterministic for a given generator state.
    public static func makeBoard(using random: inout SeededRandom, stage: Int = 1) -> Board {
        let count = initialCount(forStage: stage)
        let pairs = minimumPairs(forStage: stage)
        while true {
            let values = (0..<count).map { _ in random.nextInt(in: 1...9) }
            guard isPairable(values) else { continue }
            let board = Board(values: values)
            if MatchRules.validPairs(on: board).count >= pairs {
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
