import Foundation
import QuietNumbersCore

/// Formats daily challenge keys (`yyyy-MM-dd`, UTC days) for display.
/// Formatting happens in UTC so the shown day matches the key in every time zone.
enum DayKeyFormat {
    static func string(_ dayKey: String, date: Date.FormatStyle.DateStyle = .abbreviated) -> String {
        guard let day = DailyChallenge.date(forDayKey: dayKey) else { return dayKey }
        return day.formatted(Date.FormatStyle(date: date, time: .omitted, timeZone: .gmt))
    }
}
