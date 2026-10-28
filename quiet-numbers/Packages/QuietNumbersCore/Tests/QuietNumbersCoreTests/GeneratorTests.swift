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

    @Test(arguments: 0..<40)
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

    @Test func movesBeforePlusCountsPlayableMatches() {
        var random = SeededRandom(seed: 1)
        // Nothing pairs: stuck right away.
        #expect(BoardGenerator.movesBeforePlus(on: makeBoard([[1, 2, 1, 2, 1, 2, 1, 2, 1]]), using: &random) == 0)
        // 4-4, then 3-7 meet across the cleared pair: every order plays both.
        #expect(BoardGenerator.movesBeforePlus(on: makeBoard([[3, 4, 4, 7, 1, 2, 1, 2, 1]]), using: &random) == 2)
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

    @Test func dailyGoalIsStableAndInRange() {
        let goals = (1...60).compactMap { DailyChallenge.dayKey("2026-10-01", addingDays: $0) }.map(DailyChallenge.goal(forDayKey:))
        #expect(goals.allSatisfy { (400...700).contains($0) && $0.isMultiple(of: 50) })
        #expect(Set(goals).count > 3)
        #expect(DailyChallenge.goal(forDayKey: "2026-10-25") == DailyChallenge.goal(forDayKey: "2026-10-25"))
        #expect(DailyChallenge.session(forDayKey: "2026-10-25").goal == DailyChallenge.goal(forDayKey: "2026-10-25"))
    }

    /// Golden board for a fixed day. iPhone, iPad and Mac must all produce exactly this.
    @Test func dailyBoardGolden() {
        let values = DailyChallenge.session(forDayKey: "2026-10-25").board.cells.map(\.value)
        #expect(values == Self.golden20261025)
    }

    static let golden20261025 = [7, 5, 6, 5, 5, 9, 7, 5, 4, 9, 2, 1, 9, 8, 5, 2, 9, 2, 4, 3, 4, 5, 4, 3, 6, 3, 5, 9, 8, 9, 2, 9, 5, 9, 8, 1, 3, 4, 7, 6, 7, 8]
}
