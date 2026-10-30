import QuietCore

/// Knuth's Algorithm X with dancing links ("Dancing Links", 2000), for sudoku as exact cover.
///
/// 324 constraints: every cell holds a digit, and every row, column and box holds each digit
/// once. 729 options (cell × digit), each covering 4 constraints. A solution picks 81 options
/// that cover every constraint exactly once. Always branching on the constraint with the
/// fewest options keeps the search tiny for sudoku.
public enum DancingLinks {
    /// Up to `limit` solutions of `grid`. Givens that clash give none.
    public static func solutions(of grid: Grid, limit: Int = 2) -> [Grid] {
        var matrix = Matrix.template
        var random: SeededRandom?
        return matrix.solve(grid, limit: limit, random: &random)
    }

    /// 0, 1, or 2 (meaning "more than one").
    public static func countSolutions(_ grid: Grid, limit: Int = 2) -> Int {
        solutions(of: grid, limit: limit).count
    }

    public static func hasUniqueSolution(_ grid: Grid) -> Bool {
        countSolutions(grid) == 1
    }

    /// A random complete grid: the search tries options in an order shuffled by `random`.
    public static func randomSolution(using random: inout SeededRandom) -> Grid {
        var matrix = Matrix.template
        var optional: SeededRandom? = random
        let grid = matrix.solve(Grid(), limit: 1, random: &optional)[0]
        random = optional!
        return grid
    }

    /// The links: node 0 is the root, 1...324 the constraint headers, then 4 nodes per option.
    struct Matrix {
        static let columns = 324
        var left: [Int32] = []
        var right: [Int32] = []
        var up: [Int32] = []
        var down: [Int32] = []
        /// Header of each node.
        var header: [Int32] = []
        /// Option (cell * 9 + digit - 1) of each node.
        var option: [Int16] = []
        var size: [Int32] = []
        /// First node of each option.
        var firstNode: [Int32] = []

        static let template: Matrix = {
            var m = Matrix()
            let count = 1 + columns + 729 * 4
            m.left = Array(repeating: 0, count: count)
            m.right = m.left
            m.up = m.left
            m.down = m.left
            m.header = m.left
            m.option = Array(repeating: -1, count: count)
            m.size = Array(repeating: 0, count: columns + 1)
            m.firstNode = Array(repeating: 0, count: 729)
            for c in 0...columns {
                m.left[c] = Int32(c == 0 ? columns : c - 1)
                m.right[c] = Int32(c == columns ? 0 : c + 1)
                m.up[c] = Int32(c)
                m.down[c] = Int32(c)
                m.header[c] = Int32(c)
            }
            var node = columns + 1
            for option in 0..<729 {
                let cell = option / 9, digit = option % 9
                let row = cell / 9, column = cell % 9, box = Grid.box(of: cell)
                let constraints = [cell, 81 + row * 9 + digit, 162 + column * 9 + digit, 243 + box * 9 + digit]
                let first = node
                m.firstNode[option] = Int32(first)
                for (index, constraint) in constraints.enumerated() {
                    let h = constraint + 1
                    m.header[node] = Int32(h)
                    m.option[node] = Int16(option)
                    // Append at the bottom of the column.
                    m.up[node] = m.up[h]
                    m.down[node] = Int32(h)
                    m.down[Int(m.up[h])] = Int32(node)
                    m.up[h] = Int32(node)
                    m.size[h] += 1
                    // Circular row.
                    m.left[node] = Int32(index == 0 ? first + 3 : node - 1)
                    m.right[node] = Int32(index == 3 ? first : node + 1)
                    node += 1
                }
            }
            return m
        }()

        mutating func cover(_ c: Int) {
            right[Int(left[c])] = right[c]
            left[Int(right[c])] = left[c]
            var i = Int(down[c])
            while i != c {
                var j = Int(right[i])
                while j != i {
                    down[Int(up[j])] = down[j]
                    up[Int(down[j])] = up[j]
                    size[Int(header[j])] -= 1
                    j = Int(right[j])
                }
                i = Int(down[i])
            }
        }

        mutating func uncover(_ c: Int) {
            var i = Int(up[c])
            while i != c {
                var j = Int(left[i])
                while j != i {
                    size[Int(header[j])] += 1
                    down[Int(up[j])] = Int32(j)
                    up[Int(down[j])] = Int32(j)
                    j = Int(left[j])
                }
                i = Int(up[i])
            }
            right[Int(left[c])] = Int32(c)
            left[Int(right[c])] = Int32(c)
        }

        mutating func solve(_ grid: Grid, limit: Int, random: inout SeededRandom?) -> [Grid] {
            // Givens: take their options before searching. A constraint covered twice means
            // the givens clash.
            var covered = Array(repeating: false, count: Matrix.columns + 1)
            var chosen: [Int] = []
            for cell in 0..<81 where grid[cell] != 0 {
                let option = cell * 9 + grid[cell] - 1
                var node = Int(firstNode[option])
                for _ in 0..<4 {
                    let h = Int(header[node])
                    if covered[h] { return [] }
                    covered[h] = true
                    cover(h)
                    node = Int(right[node])
                }
                chosen.append(option)
            }
            var found: [Grid] = []
            search(&chosen, limit: limit, random: &random, found: &found)
            return found
        }

        private mutating func search(_ chosen: inout [Int], limit: Int, random: inout SeededRandom?, found: inout [Grid]) {
            if right[0] == 0 {
                var grid = Grid()
                for option in chosen { grid[option / 9] = option % 9 + 1 }
                found.append(grid)
                return
            }
            // The constraint with the fewest options left.
            var c = Int(right[0])
            var best = Int(size[c])
            var j = Int(right[c])
            while j != 0, best > 1 {
                if Int(size[j]) < best {
                    best = Int(size[j])
                    c = j
                }
                j = Int(right[j])
            }
            if best == 0 { return }
            cover(c)
            var rows: [Int] = []
            var r = Int(down[c])
            while r != c {
                rows.append(r)
                r = Int(down[r])
            }
            if var generator = random {
                // Fisher–Yates with our own generator: same order on every device.
                for i in stride(from: rows.count - 1, to: 0, by: -1) {
                    rows.swapAt(i, generator.nextInt(in: 0...i))
                }
                random = generator
            }
            for r in rows {
                chosen.append(Int(option[r]))
                var j = Int(right[r])
                while j != r {
                    cover(Int(header[j]))
                    j = Int(right[j])
                }
                search(&chosen, limit: limit, random: &random, found: &found)
                j = Int(left[r])
                while j != r {
                    uncover(Int(header[j]))
                    j = Int(left[j])
                }
                chosen.removeLast()
                if found.count >= limit { break }
            }
            uncover(c)
        }
    }
}
