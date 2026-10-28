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
        #expect(DailyChallenge.dayKey(for: date, timeZone: TimeZone(identifier: "UTC")!) == "2026-10-25")
    }

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
    private let bogota = TimeZone(identifier: "America/Bogota")!
    private let madrid = TimeZone(identifier: "Europe/Madrid")!

    @Test func rollsOverAtLocalMidnight() {
        // Bogotá is UTC-5: 23:59 local is still the 25th, 00:00 is the 26th.
        #expect(DailyChallenge.dayKey(for: date("2026-10-26T04:59:00Z"), timeZone: bogota) == "2026-10-25")
        #expect(DailyChallenge.dayKey(for: date("2026-10-26T05:00:00Z"), timeZone: bogota) == "2026-10-26")
        // The evening belongs to the same day now.
        #expect(DailyChallenge.dayKey(for: date("2026-10-26T00:30:00Z"), timeZone: bogota) == "2026-10-25")
        // Same instant, other time zone: each device follows its own clock.
        #expect(DailyChallenge.dayKey(for: date("2026-10-25T23:30:00Z"), timeZone: madrid) == "2026-10-26")
    }

    @Test func rolloverHoldsAcrossDaylightSaving() {
        // Madrid leaves summer time on 2026-10-25 at 03:00; midnight is still the change.
        #expect(DailyChallenge.dayKey(for: date("2026-10-25T22:59:00Z"), timeZone: madrid) == "2026-10-25")
        #expect(DailyChallenge.dayKey(for: date("2026-10-25T23:00:00Z"), timeZone: madrid) == "2026-10-26")
    }

    @Test func nextRolloverIsNextMidnight() {
        #expect(DailyChallenge.nextRollover(after: date("2026-10-25T15:00:00Z"), timeZone: bogota) == date("2026-10-26T05:00:00Z"))
        #expect(DailyChallenge.nextRollover(after: date("2026-10-26T05:00:00Z"), timeZone: bogota) == date("2026-10-27T05:00:00Z"))
    }

    @Test func anEveningRolloverStillWorks() {
        // The rule supports a rollover hour other than midnight (it was 19:00 before).
        #expect(DailyChallenge.dayKey(for: date("2026-10-25T23:59:00Z"), timeZone: bogota, rolloverHour: 19) == "2026-10-25")
        #expect(DailyChallenge.dayKey(for: date("2026-10-26T00:00:00Z"), timeZone: bogota, rolloverHour: 19) == "2026-10-26")
        #expect(DailyChallenge.nextRollover(after: date("2026-10-25T15:00:00Z"), timeZone: bogota, rolloverHour: 19) == date("2026-10-26T00:00:00Z"))
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
