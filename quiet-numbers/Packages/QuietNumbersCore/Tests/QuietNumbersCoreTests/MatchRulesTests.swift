import Testing
@testable import QuietNumbersCore

/// Builds a board from rows; `0` marks a cleared cell (its value is irrelevant).
func makeBoard(_ rows: [[Int]]) -> Board {
    let flat = rows.flatMap { $0 }
    var board = Board(values: flat.map { $0 == 0 ? 1 : $0 })
    for (index, value) in flat.enumerated() where value == 0 {
        board.clear(at: index)
    }
    return board
}

@Suite struct MatchRulesTests {
    @Test(arguments: [(4, 4, true), (3, 7, true), (5, 5, true), (1, 9, true), (2, 3, false), (6, 6, true), (8, 3, false)])
    func values(a: Int, b: Int, expected: Bool) {
        #expect(MatchRules.valuesMatch(a, b) == expected)
    }

    // MARK: 1. Adjacent

    @Test func adjacentHorizontal() {
        let board = makeBoard([[4, 4, 1, 2, 3, 5, 6, 8, 2]])
        #expect(MatchRules.pair(on: board, 0, 1)?.connection == .adjacent)
    }

    @Test func adjacentVertical() {
        let board = makeBoard([
            [3, 1, 2, 1, 2, 1, 2, 1, 2],
            [7, 2, 1, 2, 1, 2, 1, 2, 1],
        ])
        #expect(MatchRules.pair(on: board, 0, 9)?.connection == .adjacent)
    }

    @Test func adjacentDiagonals() {
        let board = makeBoard([
            [1, 5, 1, 2, 1, 2, 1, 2, 1],
            [5, 2, 5, 1, 2, 1, 2, 1, 2],
        ])
        #expect(MatchRules.pair(on: board, 1, 9)?.connection == .adjacent)
        #expect(MatchRules.pair(on: board, 1, 11)?.connection == .adjacent)
    }

    @Test func nonMatchingValuesAreRejected() {
        let board = makeBoard([[2, 3, 1, 2, 1, 2, 1, 2, 1]])
        #expect(MatchRules.pair(on: board, 0, 1) == nil)
    }

    @Test func clearedCellsCantBePaired() {
        let board = makeBoard([[0, 4, 4, 1, 2, 1, 2, 1, 2]])
        #expect(MatchRules.pair(on: board, 0, 1) == nil)
        #expect(MatchRules.pair(on: board, 1, 1) == nil)
    }

    // MARK: 2. Same line across cleared cells

    @Test func horizontalAcrossCleared() {
        let board = makeBoard([[6, 0, 0, 4, 1, 2, 1, 2, 1]])
        #expect(MatchRules.pair(on: board, 0, 3)?.connection == .acrossCleared)
    }

    @Test func verticalAcrossCleared() {
        let board = makeBoard([
            [8, 1, 2, 1, 2, 1, 2, 1, 2],
            [0, 2, 1, 2, 1, 2, 1, 2, 1],
            [2, 1, 2, 1, 2, 1, 2, 1, 2],
        ])
        #expect(MatchRules.pair(on: board, 0, 18)?.connection == .acrossCleared)
    }

    @Test func diagonalAcrossCleared() {
        let board = makeBoard([
            [9, 2, 1, 2, 1, 2, 1, 2, 1],
            [1, 0, 2, 1, 2, 1, 2, 1, 2],
            [2, 1, 9, 2, 1, 2, 1, 2, 1],
        ])
        #expect(MatchRules.pair(on: board, 0, 20)?.connection == .acrossCleared)
    }

    @Test func blockedLineIsRejected() {
        let board = makeBoard([
            [8, 1, 2, 1, 2, 1, 2, 1, 2],
            [3, 2, 1, 2, 1, 2, 1, 2, 1],
            [2, 1, 2, 1, 2, 1, 2, 1, 2],
        ])
        #expect(MatchRules.pair(on: board, 0, 18) == nil)
    }

    @Test func diagonalDoesNotWrapAcrossEdges() {
        // Index 8 (last column) and 16 are not diagonal neighbours of each other via wrap.
        let board = makeBoard([
            [1, 2, 1, 2, 1, 2, 1, 3, 4],
            [2, 1, 2, 1, 2, 1, 2, 1, 2],
            [4, 3, 1, 2, 1, 2, 1, 2, 1],
        ])
        #expect(MatchRules.pair(on: board, 8, 18) == nil)
    }

    // MARK: 3. Reading order

    @Test func rowWrapIsAdjacent() {
        let board = makeBoard([
            [2, 1, 2, 1, 2, 1, 2, 1, 7],
            [3, 2, 1, 2, 1, 2, 1, 2, 1],
        ])
        #expect(MatchRules.pair(on: board, 8, 9)?.connection == .adjacent)
    }

    @Test func readingOrderSkipsClearedAcrossRows() {
        let board = makeBoard([
            [2, 1, 2, 1, 2, 1, 6, 0, 0],
            [0, 0, 4, 2, 1, 2, 1, 2, 1],
        ])
        #expect(MatchRules.pair(on: board, 6, 11)?.connection == .acrossCleared)
    }

    @Test func validPairsFindsEveryPairOnce() {
        let board = makeBoard([[5, 5, 5, 2, 1, 2, 1, 2, 1]])
        let pairs = MatchRules.validPairs(on: board)
        #expect(pairs.count == 2)
        #expect(Set(pairs.map { [$0.first, $0.second] }) == [[0, 1], [1, 2]])
    }
}
