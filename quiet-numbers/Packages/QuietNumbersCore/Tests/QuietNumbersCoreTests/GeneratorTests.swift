import Foundation
import Testing
@testable import QuietNumbersCore

@Suite struct GeneratorTests {
    /// Golden values: if these change, every device would see different daily boards.
    @Test func splitMix64IsStable() {
        var random = SeededRandom(seed: 0)
        #expect(random.next() == 0xE220_A839_7B1D_CDAF)
        #expect(random.next() == 0x6E78_9E6A_A1B9_65F4)
    }

    @Test func fnv1aIsStable() {
        #expect(FNV1a.hash("") == 0xCBF2_9CE4_8422_2325)
        #expect(FNV1a.hash("a") == 0xAF63_DC4C_8601_EC8C)
    }

    @Test func boundedValuesStayInRange() {
        var random = SeededRandom(seed: 7)
        for _ in 0..<10_000 {
            #expect((1...9).contains(random.nextInt(in: 1...9)))
        }
    }

    @Test(arguments: 0..<200)
    func generatedBoardsHaveFewStartingPairs(seed: UInt64) {
        var random = SeededRandom(seed: seed)
        for stage in 1...6 {
            let board = BoardGenerator.makeBoard(using: &random, stage: stage)
            #expect(board.cells.count == BoardGenerator.initialCount(forStage: stage))
            #expect(board.cells.allSatisfy { (1...9).contains($0.value) })
            #expect(BoardGenerator.startingPairs(forStage: stage).contains(MatchRules.validPairs(on: board).count))
            #expect(BoardGenerator.isPairable(board.cells.map(\.value)))
        }
    }

    @Test(arguments: 0..<50)
    func layoutStartsWithoutPairs(seed: UInt64) {
        var random = SeededRandom(seed: seed)
        let values = BoardGenerator.valuesWithoutPairs(54, using: &random)
        #expect(MatchRules.validPairs(on: Board(values: values)).isEmpty)
    }

    @Test func pairableNeedsEveryFamilyEven() {
        #expect(BoardGenerator.isPairable([5, 5, 1, 9, 2, 2]))
        #expect(!BoardGenerator.isPairable([5, 5, 5, 1, 9, 2]))
        #expect(!BoardGenerator.isPairable([1, 2]))
        #expect(BoardGenerator.isPairable([]))
    }

    @Test func sameSeedSameBoard() {
        #expect(GameSession(seed: 1234).board == GameSession(seed: 1234).board)
        #expect(GameSession(seed: 1234).board != GameSession(seed: 1235).board)
    }

    @Test func sameKeySameDailyBoard() {
        #expect(DailyChallenge.session(forDayKey: "2026-10-25").board == DailyChallenge.session(forDayKey: "2026-10-25").board)
        #expect(DailyChallenge.session(forDayKey: "2026-10-25").board != DailyChallenge.session(forDayKey: "2026-10-26").board)
    }

    /// Golden board for a fixed day. iPhone, iPad and Mac must all produce exactly this.
    @Test func dailyBoardGolden() {
        let values = DailyChallenge.session(forDayKey: "2026-10-25").board.cells.map(\.value)
        #expect(values == Self.golden20261025)
    }

    static let golden20261025 = [5, 6, 9, 8, 7, 6, 7, 4, 4, 3, 8, 3, 4, 7, 8, 9, 2, 9, 6, 5, 9, 8, 5, 7, 4, 5, 7, 1, 7, 4, 7, 6, 8, 1, 2, 1, 6, 2, 1, 1, 1, 3]
}
