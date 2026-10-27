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

    @Test func rollsOverAt7pmLocal() {
        #expect(DailyKey.dayKey(for: date("2026-10-25T23:59:00Z"), timeZone: bogota) == "2026-10-25")
        #expect(DailyKey.dayKey(for: date("2026-10-26T00:00:00Z"), timeZone: bogota) == "2026-10-26")
        #expect(DailyKey.dayKey(for: date("2026-10-26T05:30:00Z"), timeZone: bogota) == "2026-10-26")
        #expect(DailyKey.dayKey(for: date("2026-10-25T18:30:00Z"), timeZone: madrid) == "2026-10-26")
    }

    @Test func nextRolloverIsNext7pm() {
        #expect(DailyKey.nextRollover(after: date("2026-10-25T15:00:00Z"), timeZone: bogota) == date("2026-10-26T00:00:00Z"))
        #expect(DailyKey.nextRollover(after: date("2026-10-26T00:00:00Z"), timeZone: bogota) == date("2026-10-27T00:00:00Z"))
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
