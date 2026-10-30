import Foundation
import Testing
@testable import QuietCore

@Suite struct RandomTests {
    /// Golden values, same as Quiet Numbers: if these change, every device would see
    /// different daily challenges.
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
}

@Suite struct DailyKeyTests {
    @Test func keyArithmeticCrossesMonthsAndYears() {
        #expect(DailyKey.dayKey("2026-10-31", addingDays: 1) == "2026-11-01")
        #expect(DailyKey.dayKey("2027-01-01", addingDays: -1) == "2026-12-31")
        #expect(DailyKey.dayKey("2028-02-28", addingDays: 1) == "2028-02-29")
        #expect(DailyKey.dayKey("bad", addingDays: 1) == nil)
    }

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
    private let bogota = TimeZone(identifier: "America/Bogota")!
    private let madrid = TimeZone(identifier: "Europe/Madrid")!

    @Test func rollsOverAtLocalMidnight() {
        // Bogotá is UTC-5: 23:59 local is still the 25th, midnight is the 26th.
        #expect(DailyKey.dayKey(for: date("2026-10-26T04:59:00Z"), timeZone: bogota) == "2026-10-25")
        #expect(DailyKey.dayKey(for: date("2026-10-26T05:00:00Z"), timeZone: bogota) == "2026-10-26")
        // Same instant, other time zone: each device follows its own clock.
        #expect(DailyKey.dayKey(for: date("2026-10-25T23:30:00Z"), timeZone: madrid) == "2026-10-26")
    }

    @Test func nextRolloverIsNextMidnight() {
        #expect(DailyKey.nextRollover(after: date("2026-10-25T15:00:00Z"), timeZone: bogota) == date("2026-10-26T05:00:00Z"))
        #expect(DailyKey.nextRollover(after: date("2026-10-26T05:00:00Z"), timeZone: bogota) == date("2026-10-27T05:00:00Z"))
    }

    @Test func dateRoundTripsThroughKey() throws {
        let day = try #require(DailyKey.date(forDayKey: "2026-10-25"))
        #expect(DailyKey.dayKey(for: day, timeZone: TimeZone(identifier: "UTC")!) == "2026-10-25")
    }

    @Test func theEveningBelongsToTheSameDay() {
        #expect(DailyKey.dayKey(for: date("2026-10-26T00:30:00Z"), timeZone: bogota) == "2026-10-25")
    }

    @Test func rolloverHoldsAcrossDaylightSaving() {
        // Madrid leaves summer time on 2026-10-25 at 03:00; midnight is still the change.
        #expect(DailyKey.dayKey(for: date("2026-10-25T22:59:00Z"), timeZone: madrid) == "2026-10-25")
        #expect(DailyKey.dayKey(for: date("2026-10-25T23:00:00Z"), timeZone: madrid) == "2026-10-26")
    }

    @Test func anEveningRolloverStillWorks() {
        // A rollover hour other than midnight (Quiet Numbers used 19:00 before 2026-10-27).
        #expect(DailyKey.dayKey(for: date("2026-10-25T23:59:00Z"), timeZone: bogota, rolloverHour: 19) == "2026-10-25")
        #expect(DailyKey.dayKey(for: date("2026-10-26T00:00:00Z"), timeZone: bogota, rolloverHour: 19) == "2026-10-26")
        #expect(DailyKey.nextRollover(after: date("2026-10-25T15:00:00Z"), timeZone: bogota, rolloverHour: 19) == date("2026-10-26T00:00:00Z"))
    }

    @Test func weekdayIsMondayFirst() {
        #expect(DailyKey.weekday(ofDayKey: "2026-10-26") == 1) // Monday
        #expect(DailyKey.weekday(ofDayKey: "2026-10-27") == 2)
        #expect(DailyKey.weekday(ofDayKey: "2026-11-01") == 7) // Sunday
    }

    @Test func streaks() {
        let days: Set = ["2026-10-22", "2026-10-23", "2026-10-24"]
        #expect(Streaks.current(completed: days, today: "2026-10-24") == 3)
        #expect(Streaks.current(completed: days, today: "2026-10-25") == 3)
        #expect(Streaks.current(completed: days, today: "2026-10-26") == 0)
        #expect(Streaks.current(completed: [], today: "2026-10-26") == 0)
        #expect(Streaks.longest(completed: []) == 0)
        let runs: Set = ["2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-10", "2026-10-11"]
        #expect(Streaks.longest(completed: runs) == 4)
    }
}

@Suite struct PaletteTests {
    /// Same pairs `theme-colors.py` checks in Quiet Numbers, plus red suits on card faces.
    private static let textOn: [(Palette.Role, [Palette.Role])] = [
        (.ink, [.background, .surface, .surface2]),
        (.muted, [.background, .surface]),
        (.primary, [.background, .surface, .surface2]),
        (.accent, [.background, .surface]),
        (.onPrimary, [.primary]),
        (.suitRed, [.surface]),
    ]

    @Test(arguments: Palette.allCases)
    func textPassesAA(palette: Palette) {
        for (text, backgrounds) in Self.textOn {
            for background in backgrounds {
                let t = palette.hex(text), b = palette.hex(background)
                #expect(Contrast.ratio(t.light, b.light) >= 4.5, "\(palette) light: \(text) on \(background)")
                #expect(Contrast.ratio(t.dark, b.dark) >= 4.5, "\(palette) dark: \(text) on \(background)")
            }
        }
    }
}

@Suite struct DailyReminderPlanTests {
    private let bogota = TimeZone(identifier: "America/Bogota")!

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = bogota
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func plan(_ now: Date, completed: Bool, streak: Int) -> [DailyReminderPlan.Item] {
        DailyReminderPlan.items(now: now, todayCompleted: completed, streak: streak, timeZone: bogota)
    }

    @Test func todayGetsBothWhenAStreakIsAtStake() {
        let items = plan(date(14, 10), completed: false, streak: 8)
        let today = items.filter { $0.dayKey == "2026-11-14" }
        #expect(today.map(\.kind) == [.reminder, .streakAtRisk])
        #expect(today.map(\.components.hour) == [19, 21])
        #expect(today.allSatisfy { $0.streak == 8 })
        // Later days: the plain reminder only.
        let later = items.filter { $0.dayKey != "2026-11-14" }
        #expect(later.count == DailyReminderPlan.daysAhead - 1)
        #expect(later.allSatisfy { $0.kind == .reminder && $0.streak == 0 })
    }

    @Test func atMostTwoADay() {
        let items = plan(date(14, 10), completed: false, streak: 30)
        #expect(Dictionary(grouping: items, by: \.dayKey).values.allSatisfy { $0.count <= 2 })
        #expect(Set(items.map(\.identifier)).count == items.count)
    }

    @Test func shortStreaksGetNoWarning() {
        let items = plan(date(14, 10), completed: false, streak: 2)
        #expect(items.allSatisfy { $0.kind == .reminder && $0.streak == 0 })
    }

    @Test func completingTodayMovesTheStakeToTomorrow() {
        let items = plan(date(14, 18), completed: true, streak: 9)
        #expect(!items.contains { $0.dayKey == "2026-11-14" })
        let tomorrow = items.filter { $0.dayKey == "2026-11-15" }
        #expect(tomorrow.map(\.kind) == [.reminder, .streakAtRisk])
        #expect(tomorrow.allSatisfy { $0.streak == 9 })
        #expect(items.filter { $0.kind == .streakAtRisk }.count == 1)
    }

    @Test func pastHoursAreSkipped() {
        // 20:00, not done: only the 21:00 warning is left today.
        let evening = plan(date(14, 20), completed: false, streak: 5).filter { $0.dayKey == "2026-11-14" }
        #expect(evening.map(\.kind) == [.streakAtRisk])
        // 22:00: nothing today, and tomorrow has no streak at stake (it ends tonight).
        let night = plan(date(14, 22), completed: false, streak: 5)
        #expect(!night.contains { $0.dayKey == "2026-11-14" })
        #expect(night.allSatisfy { $0.kind == .reminder && $0.streak == 0 })
    }

    @Test func duelsGoToTheHigherScoreThenTheFasterTime() {
        #expect(DailyDuel.result(mine: (900, 300), theirs: (800, 100)) == .won)
        #expect(DailyDuel.result(mine: (900, 300), theirs: (900, 200)) == .lost)
        #expect(DailyDuel.result(mine: (900, 200), theirs: (900, nil)) == .won)
        #expect(DailyDuel.result(mine: (900, 200), theirs: (900, 200)) == .tied)
        #expect(DailyDuel.result(mine: nil, theirs: (900, 200)) == .notBoth)
    }
}
