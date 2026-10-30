/// How hard a puzzle is: the hardest technique a person needs to solve it without guessing.
public enum Difficulty: Int, CaseIterable, Codable, Sendable, Comparable {
    case easy, medium, hard, expert

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// Monday and Tuesday easy, Wednesday–Friday medium, Saturday hard, Sunday expert.
    public static func forWeekday(_ weekday: Int) -> Difficulty {
        switch weekday {
        case 1, 2: .easy
        case 3, 4, 5: .medium
        case 6: .hard
        default: .expert
        }
    }
}

/// The human solving techniques the logic solver knows, easiest first. The solver always
/// uses the first one that makes progress, so the order is the grading scale.
public enum Technique: String, CaseIterable, Codable, Sendable, Comparable {
    /// The last empty cell of a row, column or box.
    case fullHouse
    /// A digit fits in only one cell of a row, column or box.
    case hiddenSingle
    /// A cell where only one digit fits.
    case nakedSingle
    /// In a box, a digit's cells all lie on one row or column: not elsewhere on that line.
    case pointing
    /// On a row or column, a digit's cells all lie in one box: not elsewhere in that box.
    case claiming
    case nakedPair
    case hiddenPair
    case nakedTriple
    case hiddenTriple
    case xWing
    case xyWing
    /// Two rows (or columns) where a digit has two spots each, one pair lined up: one of the
    /// other two ends holds it, so cells seeing both can't.
    case skyscraper
    /// A row and a column with two spots each for a digit, linked through a box.
    case twoStringKite
    case swordfish
    case xyzWing
    /// Two cells {x, y} that don't see each other, joined by a house where x has only two
    /// spots, each seen by one of them: one of the two cells is y.
    case wWing

    public var difficulty: Difficulty {
        switch self {
        case .fullHouse, .hiddenSingle, .nakedSingle: .easy
        case .pointing, .claiming, .nakedPair, .hiddenPair: .medium
        case .nakedTriple, .hiddenTriple, .xWing, .xyWing: .hard
        case .skyscraper, .twoStringKite, .swordfish, .xyzWing, .wWing: .expert
        }
    }

    private var order: Int { Technique.allCases.firstIndex(of: self)! }

    public static func < (a: Self, b: Self) -> Bool { a.order < b.order }
}

/// One deduction: either a digit placed, or candidates ruled out. `cells`, `digits` and
/// `units` are what justifies it, for the hint's highlight and explanation.
public struct Step: Hashable, Codable, Sendable {
    public let technique: Technique
    public let placement: Placement?
    public let eliminations: [Placement]
    /// The pattern: the cells whose candidates prove the step.
    public let cells: [Int]
    public let digits: [Int]
    /// Houses involved (0–8 rows, 9–17 columns, 18–26 boxes).
    public let units: [Int]

    public init(technique: Technique, placement: Placement? = nil, eliminations: [Placement] = [], cells: [Int] = [], digits: [Int] = [], units: [Int] = []) {
        self.technique = technique
        self.placement = placement
        self.eliminations = eliminations
        self.cells = cells
        self.digits = digits
        self.units = units
    }
}

/// A digit in a cell.
public struct Placement: Hashable, Codable, Sendable {
    public let cell: Int
    public let digit: Int

    public init(cell: Int, digit: Int) {
        self.cell = cell
        self.digit = digit
    }
}

/// All `k`-element subsets of `items`, in lexicographic order.
func combinations<T>(_ items: [T], _ k: Int) -> [[T]] {
    guard k > 0, items.count >= k else { return k == 0 ? [[]] : [] }
    var result: [[T]] = []
    var indices = Array(0..<k)
    while true {
        result.append(indices.map { items[$0] })
        var i = k - 1
        while i >= 0, indices[i] == items.count - k + i { i -= 1 }
        if i < 0 { return result }
        indices[i] += 1
        for j in (i + 1)..<k { indices[j] = indices[j - 1] + 1 }
    }
}
