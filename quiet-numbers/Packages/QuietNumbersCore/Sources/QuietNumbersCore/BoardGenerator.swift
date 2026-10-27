public enum BoardGenerator {
    /// Stage 1 (and every daily challenge).
    public static let initialCount = initialCount(forStage: 1)
    public static let startingPairs = startingPairs(forStage: 1)

    /// Difficulty grows with the stage: bigger boards (42 → 54 numbers by stage 5)…
    /// Always even: `isPairable` needs every family to have an even count.
    public static func initialCount(forStage stage: Int) -> Int {
        [42, 44, 48, 50, 54][min(max(stage, 1), 5) - 1]
    }

    /// …and only a few pairs to start with: 3–5, then 2–4, then 2–3 from stage 3
    /// (a random board would have about 30). Never fewer than 2, so the first move is a choice.
    public static func startingPairs(forStage stage: Int) -> ClosedRange<Int> {
        switch stage {
        case ...1: 3...5
        case 2: 2...4
        default: 2...3
        }
    }

    /// …but playing them should open more: a typical player (random order) gets at least
    /// this many matches before needing + (8, 7, then 6, then 5 from stage 5).
    public static func typicalMoves(forStage stage: Int) -> Int {
        switch stage {
        case ...1: 8
        case 2: 7
        case 3...4: 6
        default: 5
        }
    }

    /// A fresh board for `stage` with `startingPairs` valid pairs that opens up to at least
    /// `typicalMoves`, where every number could in principle find a partner (see `isPairable`).
    ///
    /// Numbers are laid out so no neighbours pair, then a few cells are changed to match a
    /// neighbour. Candidates that miss are discarded and the generator keeps advancing, so
    /// the result stays deterministic for a given generator state.
    public static func makeBoard(using random: inout SeededRandom, stage: Int = 1) -> Board {
        let count = initialCount(forStage: stage)
        let range = startingPairs(forStage: stage)
        while true {
            var values = valuesWithoutPairs(count, using: &random)
            for _ in 0..<random.nextInt(in: range) {
                plantPair(in: &values, using: &random)
            }
            guard isPairable(values) else { continue }
            let board = Board(values: values)
            guard range.contains(MatchRules.validPairs(on: board).count) else { continue }
            if movesBeforePlus(on: board, using: &random) >= typicalMoves(forStage: stage) {
                return board
            }
        }
    }

    /// Median matches over a few random playouts until no pair is left (no +). Plays on the
    /// board directly, like `GameSession.match` (a session would generate boards itself).
    static func movesBeforePlus(on board: Board, playouts: Int = 15, using random: inout SeededRandom) -> Int {
        var results: [Int] = []
        for _ in 0..<playouts {
            var current = board
            var moves = 0
            while !current.isEmpty {
                let pairs = MatchRules.validPairs(on: current)
                guard !pairs.isEmpty else { break }
                let pair = pairs[random.nextInt(in: 0...(pairs.count - 1))]
                current.clear(at: pair.first)
                current.clear(at: pair.second)
                current.removeClearedRows([current.row(of: pair.first), current.row(of: pair.second)])
                moves += 1
            }
            results.append(moves)
        }
        return results.sorted()[playouts / 2]
    }

    /// In reading order, each number avoids the families of the neighbours already placed
    /// (previous in reading order, up, up-left, up-right). At most 4 of the 5 families are
    /// taken, so there's always a choice.
    static func valuesWithoutPairs(_ count: Int, using random: inout SeededRandom) -> [Int] {
        var values: [Int] = []
        values.reserveCapacity(count)
        for index in 0..<count {
            let taken = earlierNeighbours(of: index).map { family(of: values[$0]) }
            let allowed = (1...9).filter { !taken.contains(family(of: $0)) }
            values.append(allowed[random.nextInt(in: 0...(allowed.count - 1))])
        }
        return values
    }

    /// Makes one cell pair with one of its earlier neighbours (same number or its complement).
    static func plantPair(in values: inout [Int], using random: inout SeededRandom) {
        let index = random.nextInt(in: 1...(values.count - 1))
        let neighbours = earlierNeighbours(of: index)
        let partner = values[neighbours[random.nextInt(in: 0...(neighbours.count - 1))]]
        values[index] = random.nextInt(in: 0...1) == 0 ? partner : 10 - partner
    }

    /// Neighbours placed before `index` in reading order. Every cell after the first has one.
    private static func earlierNeighbours(of index: Int) -> [Int] {
        let columns = Board.columns
        let column = index % columns
        var result: [Int] = []
        if index >= 1 { result.append(index - 1) }
        guard index >= columns else { return result }
        result.append(index - columns)
        if column > 0 { result.append(index - columns - 1) }
        if column < columns - 1 { result.append(index - columns + 1) }
        return result
    }

    private static func family(of value: Int) -> Int { min(value, 10 - value) }

    /// Numbers only ever pair within their family ({1, 9}, {2, 8}, {3, 7}, {4, 6}, {5}),
    /// so the board can only be cleared without + if every family has an even count.
    /// Necessary, not sufficient: positions can still leave a number stranded.
    public static func isPairable(_ values: [Int]) -> Bool {
        var odd = Set<Int>()
        for value in values {
            let family = family(of: value)
            if odd.remove(family) == nil { odd.insert(family) }
        }
        return odd.isEmpty
    }
}
