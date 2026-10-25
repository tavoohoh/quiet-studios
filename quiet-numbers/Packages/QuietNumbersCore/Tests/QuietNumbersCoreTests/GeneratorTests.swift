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
    func generatedBoardsHaveMinimumPairs(seed: UInt64) {
        var random = SeededRandom(seed: seed)
        let board = BoardGenerator.makeBoard(using: &random)
        #expect(board.cells.count == 27)
        #expect(board.cells.allSatisfy { (1...9).contains($0.value) })
        #expect(MatchRules.validPairs(on: board).count >= BoardGenerator.minimumPairs)
    }

    @Test func sameSeedSameBoard() {
        #expect(GameSession(seed: 1234).board == GameSession(seed: 1234).board)
        #expect(GameSession(seed: 1234).board != GameSession(seed: 1235).board)
    }

    @Test func dayKeyUsesUTC() {
        // 2026-10-25 23:30 in Bogotá (UTC-5) is already 2026-10-26 in UTC.
        let date = ISO8601DateFormatter().date(from: "2026-10-26T04:30:00Z")!
        #expect(DailyChallenge.dayKey(for: date) == "2026-10-26")
    }

    @Test func sameDateSameDailyBoard() {
        let morning = ISO8601DateFormatter().date(from: "2026-10-25T00:00:01Z")!
        let night = ISO8601DateFormatter().date(from: "2026-10-25T23:59:59Z")!
        let tomorrow = ISO8601DateFormatter().date(from: "2026-10-26T00:00:00Z")!
        #expect(DailyChallenge.session(for: morning).board == DailyChallenge.session(for: night).board)
        #expect(DailyChallenge.session(for: morning).board != DailyChallenge.session(for: tomorrow).board)
    }

    /// Golden board for a fixed date. iPhone, iPad and Mac must all produce exactly this.
    @Test func dailyBoardGolden() {
        let date = ISO8601DateFormatter().date(from: "2026-10-25T12:00:00Z")!
        let values = DailyChallenge.session(for: date).board.cells.map(\.value)
        #expect(values == Self.golden20261025)
    }

    static let golden20261025 = [5, 9, 3, 7, 6, 3, 8, 4, 5, 9, 9, 3, 3, 1, 7, 8, 9, 6, 9, 1, 9, 5, 3, 5, 1, 3, 6]
}
