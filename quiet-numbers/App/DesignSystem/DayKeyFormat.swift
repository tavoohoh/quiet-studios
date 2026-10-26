import Foundation
import QuietNumbersCore

/// Formats daily challenge keys (`yyyy-MM-dd`) for display. The key is a calendar label,
/// so it's formatted in UTC (where `date(forDayKey:)` puts it) to show that same day.
enum DayKeyFormat {
    static func string(_ dayKey: String, date: Date.FormatStyle.DateStyle = .abbreviated) -> String {
        guard let day = DailyChallenge.date(forDayKey: dayKey) else { return dayKey }
        return day.formatted(Date.FormatStyle(date: date, time: .omitted, timeZone: .gmt))
    }
}
