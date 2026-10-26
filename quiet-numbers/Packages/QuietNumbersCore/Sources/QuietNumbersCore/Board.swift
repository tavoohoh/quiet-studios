/// A single number on the board. Cleared cells stay as "ghosts" until their row empties.
public struct Cell: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let value: Int
    public var isCleared: Bool
    /// Added with +, as opposed to the stage's original numbers.
    public let isAdded: Bool

    public init(id: Int, value: Int, isCleared: Bool = false, isAdded: Bool = false) {
        self.id = id
        self.value = value
        self.isCleared = isCleared
        self.isAdded = isAdded
    }
}

/// The grid, stored as a reading-order strip of cells `columns` wide.
/// The last row may be partial.
public struct Board: Codable, Hashable, Sendable {
    public static let columns = 9

    public private(set) var cells: [Cell]
    /// Next id to hand out, so ids stay unique for the whole session (SwiftUI identity).
    private var nextID: Int

    public init(values: [Int]) {
        cells = values.enumerated().map { Cell(id: $0.offset, value: $0.element) }
        nextID = values.count
    }

    public var rowCount: Int { (cells.count + Self.columns - 1) / Self.columns }
    public var isEmpty: Bool { cells.allSatisfy(\.isCleared) }
    public var activeValues: [Int] { cells.filter { !$0.isCleared }.map(\.value) }

    public func row(of index: Int) -> Int { index / Self.columns }
    public func column(of index: Int) -> Int { index % Self.columns }
    public func index(ofCell id: Int) -> Int? { cells.firstIndex { $0.id == id } }

    public func isRowCleared(_ row: Int) -> Bool {
        rowRange(row).allSatisfy { cells[$0].isCleared }
    }

    /// A copy with the given cells cleared but every row kept, so the UI can
    /// show a match before its rows collapse.
    public func clearing(_ indices: [Int]) -> Board {
        var copy = self
        for index in indices { copy.clear(at: index) }
        return copy
    }

    mutating func clear(at index: Int) {
        cells[index].isCleared = true
    }

    /// Appends `values` as new cells at the end of the strip.
    mutating func append(_ values: [Int]) {
        for value in values {
            cells.append(Cell(id: nextID, value: value, isAdded: true))
            nextID += 1
        }
    }

    /// Removes the given rows (if they are fully cleared) and shifts the board up.
    /// Returns the rows actually removed.
    @discardableResult
    mutating func removeClearedRows(_ rows: Set<Int>) -> [Int] {
        let removable = rows.filter { $0 < rowCount && isRowCleared($0) }.sorted(by: >)
        for row in removable {
            cells.removeSubrange(rowRange(row))
        }
        return removable.sorted()
    }

    private func rowRange(_ row: Int) -> Range<Int> {
        let start = row * Self.columns
        return start..<min(start + Self.columns, cells.count)
    }
}
