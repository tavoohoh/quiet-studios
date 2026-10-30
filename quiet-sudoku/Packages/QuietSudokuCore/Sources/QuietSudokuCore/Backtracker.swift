/// A second, independent solver: plain backtracking on bit masks, filling the cell with the
/// fewest options first. Slower than `DancingLinks` on hard grids but simple enough to trust;
/// tests check that both always agree.
public enum Backtracker {
    /// 0, 1, or `limit` (meaning "at least that many").
    public static func countSolutions(_ grid: Grid, limit: Int = 2) -> Int {
        var state = State()
        for cell in 0..<81 where grid[cell] != 0 {
            guard state.allowed(cell) & Digits.bit(grid[cell]) != 0 else { return 0 }
            state.set(cell, grid[cell])
        }
        var count = 0
        state.search(limit: limit, count: &count)
        return count
    }

    struct State {
        var cells = Array(repeating: 0, count: 81)
        var rows = Array(repeating: UInt16(0), count: 9)
        var columns = Array(repeating: UInt16(0), count: 9)
        var boxes = Array(repeating: UInt16(0), count: 9)

        func allowed(_ cell: Int) -> UInt16 {
            Digits.all & ~(rows[Grid.row(of: cell)] | columns[Grid.column(of: cell)] | boxes[Grid.box(of: cell)])
        }

        mutating func set(_ cell: Int, _ digit: Int) {
            let bit = Digits.bit(digit)
            cells[cell] = digit
            rows[Grid.row(of: cell)] |= bit
            columns[Grid.column(of: cell)] |= bit
            boxes[Grid.box(of: cell)] |= bit
        }

        mutating func clear(_ cell: Int) {
            let bit = ~Digits.bit(cells[cell])
            cells[cell] = 0
            rows[Grid.row(of: cell)] &= bit
            columns[Grid.column(of: cell)] &= bit
            boxes[Grid.box(of: cell)] &= bit
        }

        mutating func search(limit: Int, count: inout Int) {
            var best = -1
            var bestMask: UInt16 = 0
            var fewest = 10
            for cell in 0..<81 where cells[cell] == 0 {
                let mask = allowed(cell)
                let options = mask.nonzeroBitCount
                if options < fewest {
                    fewest = options
                    best = cell
                    bestMask = mask
                    if options <= 1 { break }
                }
            }
            if best < 0 {
                count += 1
                return
            }
            for digit in Digits.list(bestMask) {
                set(best, digit)
                search(limit: limit, count: &count)
                clear(best)
                if count >= limit { return }
            }
        }
    }
}
