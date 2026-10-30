/// Solves like a person: candidates per cell and, at every step, the easiest technique that
/// makes progress (the approach of Sudoku Explainer and HoDoKu). The hardest technique used
/// grades the puzzle, and the next step is what a hint shows.
///
/// Every step is sound, so a grid this solver completes has exactly one solution.
public struct LogicSolver: Hashable, Sendable {
    public private(set) var values: [Int]
    /// Candidates of empty cells; 0 for filled ones.
    public private(set) var candidates: [UInt16]

    public init(_ grid: Grid) {
        values = grid.cells
        candidates = Array(repeating: 0, count: 81)
        for cell in 0..<81 where values[cell] == 0 {
            var mask = Digits.all
            for peer in Grid.peers[cell] where values[peer] != 0 {
                mask &= ~Digits.bit(values[peer])
            }
            candidates[cell] = mask
        }
    }

    public var grid: Grid { Grid(cells: values) }
    public var isSolved: Bool { !values.contains(0) }

    /// What solving a whole grid took.
    public struct Result: Hashable, Sendable {
        public let solved: Bool
        public let steps: [Step]
        public let grid: Grid

        /// The hardest technique used, if any step was needed.
        public var hardest: Technique? { steps.map(\.technique).max() }
        /// The puzzle's level, or nil if the techniques allowed weren't enough.
        public var difficulty: Difficulty? { solved ? (hardest?.difficulty ?? .easy) : nil }
    }

    /// Solves as far as the techniques up to `level` allow.
    public static func solve(_ grid: Grid, upTo level: Difficulty = .expert) -> Result {
        var solver = LogicSolver(grid)
        var steps: [Step] = []
        while !solver.isSolved, let step = solver.nextStep(upTo: level) {
            solver.apply(step)
            steps.append(step)
        }
        return Result(solved: solver.isSolved, steps: steps, grid: solver.grid)
    }

    /// The level of a puzzle, or nil when it needs more than the solver knows.
    public static func grade(_ grid: Grid) -> Difficulty? {
        solve(grid).difficulty
    }

    public mutating func apply(_ step: Step) {
        if let placement = step.placement { place(placement.digit, at: placement.cell) }
        for elimination in step.eliminations {
            candidates[elimination.cell] &= ~Digits.bit(elimination.digit)
        }
    }

    public mutating func place(_ digit: Int, at cell: Int) {
        values[cell] = digit
        candidates[cell] = 0
        let bit = ~Digits.bit(digit)
        for peer in Grid.peers[cell] { candidates[peer] &= bit }
    }

    /// The easiest step available with techniques up to `level`.
    public func nextStep(upTo level: Difficulty = .expert) -> Step? {
        for technique in Technique.allCases where technique.difficulty <= level {
            if let step = find(technique) { return step }
        }
        return nil
    }

    /// The first instance of one technique, if it makes progress.
    public func find(_ technique: Technique) -> Step? {
        switch technique {
        case .fullHouse: fullHouse()
        case .hiddenSingle: hiddenSingle()
        case .nakedSingle: nakedSingle()
        case .pointing: pointing()
        case .claiming: claiming()
        case .nakedPair: nakedSubset(2, technique)
        case .nakedTriple: nakedSubset(3, technique)
        case .hiddenPair: hiddenSubset(2, technique)
        case .hiddenTriple: hiddenSubset(3, technique)
        case .xWing: fish(2, technique)
        case .swordfish: fish(3, technique)
        case .xyWing: xyWing()
        case .xyzWing: xyzWing()
        case .skyscraper: skyscraper()
        case .twoStringKite: twoStringKite()
        case .wWing: wWing()
        }
    }

    // MARK: Singles

    private func fullHouse() -> Step? {
        for unit in 0..<27 {
            let empty = Grid.units[unit].filter { values[$0] == 0 }
            guard empty.count == 1, candidates[empty[0]].nonzeroBitCount == 1 else { continue }
            let cell = empty[0]
            return Step(technique: .fullHouse, placement: Placement(cell: cell, digit: Digits.single(candidates[cell])), cells: Grid.units[unit], units: [unit])
        }
        return nil
    }

    /// Boxes first: that's where people look for them.
    private func hiddenSingle() -> Step? {
        for unit in Array(18..<27) + Array(0..<18) {
            for digit in 1...9 {
                let bit = Digits.bit(digit)
                let spots = Grid.units[unit].filter { candidates[$0] & bit != 0 }
                guard spots.count == 1 else { continue }
                // The digit's other copies are what rule out the rest of the house.
                let blockers = Grid.units[unit].flatMap { cell in
                    values[cell] == 0 && cell != spots[0] ? Grid.peers[cell].filter { values[$0] == digit } : []
                }
                return Step(technique: .hiddenSingle, placement: Placement(cell: spots[0], digit: digit), cells: Array(Set(blockers)).sorted(), digits: [digit], units: [unit])
            }
        }
        return nil
    }

    private func nakedSingle() -> Step? {
        for cell in 0..<81 where values[cell] == 0 && candidates[cell].nonzeroBitCount == 1 {
            return Step(technique: .nakedSingle, placement: Placement(cell: cell, digit: Digits.single(candidates[cell])), cells: Grid.peers[cell].filter { values[$0] != 0 }, units: Grid.unitsOfCell[cell])
        }
        return nil
    }

    // MARK: Locked candidates

    private func pointing() -> Step? {
        for box in 18..<27 {
            for digit in 1...9 {
                let spots = cells(of: digit, in: box)
                guard spots.count >= 2 else { continue }
                for line in [Grid.row(of: spots[0]), 9 + Grid.column(of: spots[0])] where spots.allSatisfy({ Grid.unitsOfCell[$0].contains(line) }) {
                    let removed = cells(of: digit, in: line).filter { !spots.contains($0) }
                    if !removed.isEmpty {
                        return Step(technique: .pointing, eliminations: removed.map { Placement(cell: $0, digit: digit) }, cells: spots, digits: [digit], units: [box, line])
                    }
                }
            }
        }
        return nil
    }

    private func claiming() -> Step? {
        for line in 0..<18 {
            for digit in 1...9 {
                let spots = cells(of: digit, in: line)
                guard spots.count >= 2 else { continue }
                let box = 18 + Grid.box(of: spots[0])
                guard spots.allSatisfy({ 18 + Grid.box(of: $0) == box }) else { continue }
                let removed = cells(of: digit, in: box).filter { !spots.contains($0) }
                if !removed.isEmpty {
                    return Step(technique: .claiming, eliminations: removed.map { Placement(cell: $0, digit: digit) }, cells: spots, digits: [digit], units: [line, box])
                }
            }
        }
        return nil
    }

    // MARK: Subsets

    /// `size` cells of a house holding only `size` digits between them: those digits go
    /// there, so not in the house's other cells.
    private func nakedSubset(_ size: Int, _ technique: Technique) -> Step? {
        for unit in 0..<27 {
            let empty = Grid.units[unit].filter { values[$0] == 0 }
            let small = empty.filter { (2...size).contains(candidates[$0].nonzeroBitCount) }
            for group in combinations(small, size) {
                let mask = group.reduce(UInt16(0)) { $0 | candidates[$1] }
                guard mask.nonzeroBitCount == size else { continue }
                let removed = empty.filter { !group.contains($0) }.flatMap { cell in
                    Digits.list(candidates[cell] & mask).map { Placement(cell: cell, digit: $0) }
                }
                if !removed.isEmpty {
                    return Step(technique: technique, eliminations: removed, cells: group, digits: Digits.list(mask), units: [unit])
                }
            }
        }
        return nil
    }

    /// `size` digits that fit in only the same `size` cells of a house: those cells hold
    /// nothing else.
    private func hiddenSubset(_ size: Int, _ technique: Technique) -> Step? {
        for unit in 0..<27 {
            let placed = Grid.units[unit].reduce(UInt16(0)) { values[$1] == 0 ? $0 : $0 | Digits.bit(values[$1]) }
            let digits = (1...9).filter { digit in
                placed & Digits.bit(digit) == 0 && (2...size).contains(cells(of: digit, in: unit).count)
            }
            for group in combinations(digits, size) {
                let spots = Set(group.flatMap { cells(of: $0, in: unit) })
                guard spots.count == size else { continue }
                let mask = group.reduce(UInt16(0)) { $0 | Digits.bit($1) }
                let removed = spots.sorted().flatMap { cell in
                    Digits.list(candidates[cell] & ~mask).map { Placement(cell: cell, digit: $0) }
                }
                if !removed.isEmpty {
                    return Step(technique: technique, eliminations: removed, cells: spots.sorted(), digits: group, units: [unit])
                }
            }
        }
        return nil
    }

    // MARK: Fish

    /// X-Wing (2) and Swordfish (3): a digit confined to the same `size` columns on `size`
    /// rows must take those columns there, so not on any other row of them (and the same
    /// with rows and columns swapped).
    private func fish(_ size: Int, _ technique: Technique) -> Step? {
        for digit in 1...9 {
            for byRows in [true, false] {
                let bases = byRows ? Array(0..<9) : Array(9..<18)
                let lines = bases.filter { (2...size).contains(cells(of: digit, in: $0).count) }
                for group in combinations(lines, size) {
                    let spots = group.flatMap { cells(of: digit, in: $0) }
                    let covers = Set(spots.map { byRows ? 9 + Grid.column(of: $0) : Grid.row(of: $0) })
                    guard covers.count == size else { continue }
                    let removed = covers.sorted().flatMap { cells(of: digit, in: $0) }.filter { !spots.contains($0) }
                    if !removed.isEmpty {
                        return Step(technique: technique, eliminations: removed.map { Placement(cell: $0, digit: digit) }, cells: spots, digits: [digit], units: group + covers.sorted())
                    }
                }
            }
        }
        return nil
    }

    // MARK: Wings

    /// A pivot {x, y} seeing pincers {x, z} and {y, z}: whichever the pivot is, one pincer
    /// is z, so a cell seeing both pincers can't be z.
    private func xyWing() -> Step? {
        for pivot in 0..<81 where candidates[pivot].nonzeroBitCount == 2 {
            let p = candidates[pivot]
            let wings = Grid.peers[pivot].filter {
                let c = candidates[$0]
                return c.nonzeroBitCount == 2 && (c & p).nonzeroBitCount == 1
            }
            for (i, a) in wings.enumerated() {
                for b in wings[(i + 1)...] {
                    let ca = candidates[a], cb = candidates[b]
                    let z = ca & cb & ~p
                    guard z.nonzeroBitCount == 1, (ca | cb | p).nonzeroBitCount == 3, ca != cb else { continue }
                    let digit = Digits.single(z)
                    let removed = (0..<81).filter { cell in
                        cell != pivot && candidates[cell] & z != 0 && Grid.sees(cell, a) && Grid.sees(cell, b)
                    }
                    if !removed.isEmpty {
                        return Step(technique: .xyWing, eliminations: removed.map { Placement(cell: $0, digit: digit) }, cells: [pivot, a, b], digits: Digits.list(ca | cb | p))
                    }
                }
            }
        }
        return nil
    }

    /// A pivot {x, y, z} seeing pincers {x, z} and {y, z}: z is in one of the three, so a
    /// cell seeing all three can't be z.
    private func xyzWing() -> Step? {
        for pivot in 0..<81 where candidates[pivot].nonzeroBitCount == 3 {
            let p = candidates[pivot]
            let wings = Grid.peers[pivot].filter {
                let c = candidates[$0]
                return c.nonzeroBitCount == 2 && c & ~p == 0
            }
            for (i, a) in wings.enumerated() {
                for b in wings[(i + 1)...] {
                    let ca = candidates[a], cb = candidates[b]
                    let z = ca & cb
                    guard ca != cb, z.nonzeroBitCount == 1 else { continue }
                    let digit = Digits.single(z)
                    let removed = (0..<81).filter { cell in
                        cell != pivot && cell != a && cell != b && candidates[cell] & z != 0
                            && Grid.sees(cell, pivot) && Grid.sees(cell, a) && Grid.sees(cell, b)
                    }
                    if !removed.isEmpty {
                        return Step(technique: .xyzWing, eliminations: removed.map { Placement(cell: $0, digit: digit) }, cells: [pivot, a, b], digits: Digits.list(p))
                    }
                }
            }
        }
        return nil
    }

    // MARK: Single-digit patterns

    /// Houses where `digit` has exactly two spots (a strong link: one of them holds it).
    private func strongLinks(_ digit: Int, in units: Range<Int>) -> [(unit: Int, a: Int, b: Int)] {
        units.compactMap { unit in
            let spots = cells(of: digit, in: unit)
            return spots.count == 2 ? (unit, spots[0], spots[1]) : nil
        }
    }

    /// Cells holding `digit` as a candidate that see both `a` and `b`.
    private func seeingBoth(_ a: Int, _ b: Int, digit: Int, except: [Int]) -> [Int] {
        let bit = Digits.bit(digit)
        return (0..<81).filter { cell in
            candidates[cell] & bit != 0 && !except.contains(cell) && Grid.sees(cell, a) && Grid.sees(cell, b)
        }
    }

    private func skyscraper() -> Step? {
        for digit in 1...9 {
            for (lines, across) in [(0..<9, { (c: Int) in Grid.column(of: c) }), (9..<18, { (c: Int) in Grid.row(of: c) })] {
                let links = strongLinks(digit, in: lines)
                for (i, first) in links.enumerated() {
                    for second in links[(i + 1)...] {
                        for (baseA, roofA) in [(first.a, first.b), (first.b, first.a)] {
                            for (baseB, roofB) in [(second.a, second.b), (second.b, second.a)] {
                                // The bases line up; the roofs don't (that would be an X-Wing).
                                guard across(baseA) == across(baseB), across(roofA) != across(roofB) else { continue }
                                let pattern = [baseA, roofA, baseB, roofB]
                                let removed = seeingBoth(roofA, roofB, digit: digit, except: pattern)
                                if !removed.isEmpty {
                                    return Step(technique: .skyscraper, eliminations: removed.map { Placement(cell: $0, digit: digit) }, cells: pattern, digits: [digit], units: [first.unit, second.unit])
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    private func twoStringKite() -> Step? {
        for digit in 1...9 {
            for row in strongLinks(digit, in: 0..<9) {
                for column in strongLinks(digit, in: 9..<18) {
                    for (rowBox, rowEnd) in [(row.a, row.b), (row.b, row.a)] {
                        for (columnBox, columnEnd) in [(column.a, column.b), (column.b, column.a)] {
                            let box = Grid.box(of: rowBox)
                            guard rowBox != columnBox, Grid.box(of: columnBox) == box,
                                  Grid.box(of: rowEnd) != box, Grid.box(of: columnEnd) != box,
                                  rowEnd != columnEnd else { continue }
                            let pattern = [rowEnd, rowBox, columnBox, columnEnd]
                            let removed = seeingBoth(rowEnd, columnEnd, digit: digit, except: pattern)
                            if !removed.isEmpty {
                                return Step(technique: .twoStringKite, eliminations: removed.map { Placement(cell: $0, digit: digit) }, cells: pattern, digits: [digit], units: [row.unit, column.unit, 18 + box])
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    private func wWing() -> Step? {
        let pairs = (0..<81).filter { candidates[$0].nonzeroBitCount == 2 }
        for (i, a) in pairs.enumerated() {
            for b in pairs[(i + 1)...] where candidates[a] == candidates[b] && !Grid.sees(a, b) {
                let digits = Digits.list(candidates[a])
                for (x, y) in [(digits[0], digits[1]), (digits[1], digits[0])] {
                    for link in strongLinks(x, in: 0..<27) {
                        for (p, q) in [(link.a, link.b), (link.b, link.a)] {
                            guard ![a, b].contains(p), ![a, b].contains(q), Grid.sees(p, a), Grid.sees(q, b) else { continue }
                            let removed = seeingBoth(a, b, digit: y, except: [a, b])
                            if !removed.isEmpty {
                                return Step(technique: .wWing, eliminations: removed.map { Placement(cell: $0, digit: y) }, cells: [a, p, q, b], digits: [x, y], units: [link.unit])
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: Helpers

    /// Empty cells of a house where `digit` is still a candidate.
    private func cells(of digit: Int, in unit: Int) -> [Int] {
        let bit = Digits.bit(digit)
        return Grid.units[unit].filter { candidates[$0] & bit != 0 }
    }
}
