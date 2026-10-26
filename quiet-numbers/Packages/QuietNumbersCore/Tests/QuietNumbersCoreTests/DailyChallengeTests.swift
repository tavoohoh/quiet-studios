import Foundation
import Testing
@testable import QuietNumbersCore

@Suite struct DailyChallengeTests {
    @Test func keyArithmeticCrossesMonthsAndYears() {
        #expect(DailyChallenge.dayKey("2026-10-31", addingDays: 1) == "2026-11-01")
        #expect(DailyChallenge.dayKey("2027-01-01", addingDays: -1) == "2026-12-31")
        #expect(DailyChallenge.dayKey("2028-02-28", addingDays: 1) == "2028-02-29")
        #expect(DailyChallenge.dayKey("bad", addingDays: 1) == nil)
    }

    @Test func dateRoundTripsThroughKey() throws {
        let date = try #require(DailyChallenge.date(forDayKey: "2026-10-25"))
        #expect(DailyChallenge.dayKey(for: date) == "2026-10-25")
    }

    @Test func sessionForKeyMatchesSessionForDate() {
        let date = ISO8601DateFormatter().date(from: "2026-10-25T15:00:00Z")!
        #expect(DailyChallenge.session(forDayKey: "2026-10-25") == DailyChallenge.session(for: date))
    }

    @Test func currentStreakEndsTodayOrYesterday() {
        let days: Set = ["2026-10-22", "2026-10-23", "2026-10-24"]
        #expect(Streaks.current(completed: days, today: "2026-10-24") == 3)
        // Today not played yet: yesterday's streak is still alive.
        #expect(Streaks.current(completed: days, today: "2026-10-25") == 3)
        // Missed a whole day: streak is gone.
        #expect(Streaks.current(completed: days, today: "2026-10-26") == 0)
        #expect(Streaks.current(completed: [], today: "2026-10-26") == 0)
    }

    @Test func longestStreakFindsLongestRun() {
        let days: Set = ["2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-10", "2026-10-11"]
        #expect(Streaks.longest(completed: days) == 4)
        #expect(Streaks.longest(completed: []) == 0)
    }
}
