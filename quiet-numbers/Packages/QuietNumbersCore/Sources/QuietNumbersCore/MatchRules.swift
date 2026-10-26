/// How two cells reach each other. Drives scoring.
public enum Connection: String, Codable, Sendable {
    /// Neighbours on the grid, or consecutive in reading order.
    case adjacent
    /// Only cleared cells between them.
    case acrossCleared
}

/// A matchable pair, as board indices with `first < second`.
public struct Pair: Hashable, Codable, Sendable {
    public let first: Int
    public let second: Int
    /// Cleared cells between the two.
    public let gap: Int

    public var connection: Connection { gap == 0 ? .adjacent : .acrossCleared }

    public init(_ a: Int, _ b: Int, gap: Int) {
        first = min(a, b)
        second = max(a, b)
        self.gap = gap
    }
}

public enum MatchRules {
    /// Equal numbers or numbers that add up to 10.
    public static func valuesMatch(_ a: Int, _ b: Int) -> Bool {
        a == b || a + b == 10
    }

    /// Cleared cells along the shortest path between two active cells,
    /// or `nil` if they can't reach each other. Ignores values; see `pair(on:_:_:)`.
    public static func gap(on board: Board, _ a: Int, _ b: Int) -> Int? {
        guard a != b else { return nil }
        let (from, to) = (min(a, b), max(a, b))
        return reachableCells(on: board, from: from)
            .filter { $0.index == to }
            .map(\.gap)
            .min()
    }

    /// A valid pair for the two cells, or `nil`.
    public static func pair(on board: Board, _ a: Int, _ b: Int) -> Pair? {
        let cells = board.cells
        guard cells.indices.contains(a), cells.indices.contains(b),
              !cells[a].isCleared, !cells[b].isCleared,
              valuesMatch(cells[a].value, cells[b].value),
              let gap = gap(on: board, a, b)
        else { return nil }
        return Pair(a, b, gap: gap)
    }

    /// Every valid pair on the board, in reading order of the first cell.
    public static func validPairs(on board: Board) -> [Pair] {
        var pairs: [Pair] = []
        var seen: Set<[Int]> = []
        for index in board.cells.indices where !board.cells[index].isCleared {
            for (target, _) in reachableCells(on: board, from: index) {
                guard seen.insert([index, target]).inserted,
                      let pair = pair(on: board, index, target)
                else { continue }
                pairs.append(pair)
            }
        }
        return pairs
    }

    public static func hasValidPair(on board: Board) -> Bool {
        for index in board.cells.indices where !board.cells[index].isCleared {
            for (target, _) in reachableCells(on: board, from: index)
            where valuesMatch(board.cells[index].value, board.cells[target].value) {
                return true
            }
        }
        return false
    }

    /// First active cell after `index` in each forward direction: reading order,
    /// down, down-left and down-right. Backward directions are covered by symmetry.
    /// `gap` counts the cleared cells in between.
    private static func reachableCells(on board: Board, from index: Int) -> [(index: Int, gap: Int)] {
        let cells = board.cells
        let columns = Board.columns
        var result: [(index: Int, gap: Int)] = []

        // Reading order: covers horizontal and the row wrap.
        var next = index + 1
        while next < cells.count, cells[next].isCleared { next += 1 }
        if next < cells.count { result.append((next, next - index - 1)) }

        // Vertical and diagonals.
        let startColumn = board.column(of: index)
        for columnStep in [0, -1, 1] {
            var row = board.row(of: index) + 1
            var column = startColumn + columnStep
            var gap = 0
            while column >= 0, column < columns {
                let target = row * columns + column
                guard target < cells.count else { break }
                if !cells[target].isCleared {
                    result.append((target, gap))
                    break
                }
                gap += 1
                row += 1
                column += columnStep
            }
        }
        return result
    }
}
