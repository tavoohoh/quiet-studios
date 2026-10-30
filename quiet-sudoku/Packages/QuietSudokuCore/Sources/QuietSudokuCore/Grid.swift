/// A 9×9 board: 81 cells, row by row, 0 for empty and 1–9 for a digit.
public struct Grid: Hashable, Codable, Sendable {
    public var cells: [Int]

    public init(cells: [Int] = Array(repeating: 0, count: 81)) {
        precondition(cells.count == 81)
        self.cells = cells
    }

    /// 81 characters, row by row: `1`–`9` for digits and `.` or `0` for empty.
    public init?(_ string: String) {
        let cells = string.compactMap { character -> Int? in
            if character == "." { return 0 }
            guard let digit = character.wholeNumberValue, (0...9).contains(digit) else { return nil }
            return digit
        }
        guard cells.count == 81 else { return nil }
        self.cells = cells
    }

    public subscript(cell: Int) -> Int {
        get { cells[cell] }
        set { cells[cell] = newValue }
    }

    /// Digits row by row, `.` for empty.
    public var string: String {
        String(cells.map { $0 == 0 ? "." : Character(String($0)) })
    }

    public var filledCount: Int { cells.count { $0 != 0 } }
    public var isFull: Bool { !cells.contains(0) }

    /// No digit repeats in any row, column or box (empty cells allowed).
    public var isConsistent: Bool {
        Grid.units.allSatisfy { unit in
            var seen: UInt16 = 0
            for cell in unit where cells[cell] != 0 {
                let bit = Digits.bit(cells[cell])
                if seen & bit != 0 { return false }
                seen |= bit
            }
            return true
        }
    }

    public var isSolved: Bool { isFull && isConsistent }

    // MARK: Geometry

    public static func row(of cell: Int) -> Int { cell / 9 }
    public static func column(of cell: Int) -> Int { cell % 9 }
    public static func box(of cell: Int) -> Int { (cell / 27) * 3 + (cell % 9) / 3 }
    public static func cell(row: Int, column: Int) -> Int { row * 9 + column }

    /// The 27 houses: rows 0–8, columns 9–17, boxes 18–26.
    public static let units: [[Int]] = {
        let rows = (0..<9).map { r in (0..<9).map { r * 9 + $0 } }
        let columns = (0..<9).map { c in (0..<9).map { $0 * 9 + c } }
        let boxes = (0..<9).map { b in (0..<81).filter { box(of: $0) == b } }
        return rows + columns + boxes
    }()

    /// For each cell: its row, column and box unit indices.
    public static let unitsOfCell: [[Int]] = (0..<81).map { [row(of: $0), 9 + column(of: $0), 18 + box(of: $0)] }

    /// The 20 cells that share a house with each cell.
    public static let peers: [[Int]] = (0..<81).map { cell in
        Array(Set(unitsOfCell[cell].flatMap { units[$0] })).filter { $0 != cell }.sorted()
    }

    public static func sees(_ a: Int, _ b: Int) -> Bool {
        a != b && (row(of: a) == row(of: b) || column(of: a) == column(of: b) || box(of: a) == box(of: b))
    }
}

/// Unit kinds, for explanations.
public enum UnitKind: Int, Codable, Sendable {
    case row, column, box

    public init(unit: Int) { self = UnitKind(rawValue: unit / 9)! }
}

/// Sets of digits 1–9 as bit masks (bit 0 = digit 1).
public enum Digits {
    public static let all: UInt16 = 0x1FF

    @inline(__always) public static func bit(_ digit: Int) -> UInt16 { 1 << UInt16(digit - 1) }

    public static func list(_ mask: UInt16) -> [Int] {
        (1...9).filter { mask & bit($0) != 0 }
    }

    /// The only digit in a one-digit mask.
    @inline(__always) public static func single(_ mask: UInt16) -> Int { mask.trailingZeroBitCount + 1 }
}
