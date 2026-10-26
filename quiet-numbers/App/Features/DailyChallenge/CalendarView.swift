import QuietNumbersCore
import SwiftUI

/// Month grid of daily challenges. Completed days are filled, played ones outlined.
/// Days within the replay window can be tapped to play them unscored.
struct CalendarView: View {
    @Binding var month: Date
    let todayKey: String
    let records: [String: DailyRecord]
    let onSelect: (String) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel(Text("Previous month"))
                Spacer()
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(isCurrentMonth)
                .accessibilityLabel(Text("Next month"))
            }
            .buttonStyle(.borderless)

            LazyVGrid(columns: columns, spacing: 6) {
                // One ForEach with distinct ids: sibling ForEach ids collide inside a grid.
                ForEach(items, id: \.self) { item in
                    switch item {
                    case .weekday(let index):
                        Text(weekdaySymbols[index])
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    case .blank:
                        Color.clear.frame(height: 1)
                    case .day(let day):
                        DayCell(
                            day: day,
                            dayKey: dayKey(for: day),
                            todayKey: todayKey,
                            record: records[dayKey(for: day)],
                            isPlayable: isPlayable(dayKey(for: day)),
                            onSelect: onSelect
                        )
                    }
                }
            }
        }
    }

    // MARK: Layout

    private enum Item: Hashable {
        case weekday(Int)
        case blank(Int)
        case day(Int)
    }

    private var items: [Item] {
        weekdaySymbols.indices.map(Item.weekday) + (0..<leadingBlanks).map(Item.blank) + days.map(Item.day)
    }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: month)?.start ?? month
    }

    private var days: [Int] {
        Array(calendar.range(of: .day, in: .month, for: month) ?? 1..<31)
    }

    private var leadingBlanks: Int {
        (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private func shiftMonth(by value: Int) {
        if let shifted = calendar.date(byAdding: .month, value: value, to: month) {
            month = shifted
        }
    }

    /// Grid days are plain calendar dates, so their key is just their components.
    private func dayKey(for day: Int) -> String {
        let parts = calendar.dateComponents([.year, .month], from: month)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, day)
    }

    private func isPlayable(_ key: String) -> Bool {
        guard let oldest = DailyChallenge.dayKey(todayKey, addingDays: -DailyChallenge.replayWindow) else { return false }
        return key <= todayKey && key >= oldest
    }
}

private struct DayCell: View {
    let day: Int
    let dayKey: String
    let todayKey: String
    let record: DailyRecord?
    let isPlayable: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Button {
            onSelect(dayKey)
        } label: {
            Text(day, format: .number)
                .font(.system(.callout, design: .rounded, weight: dayKey == todayKey ? .bold : .regular).monospacedDigit())
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if record?.isCompleted == true {
                        Circle().fill(.tint)
                    } else if record?.isFinished == true {
                        Circle().strokeBorder(.tint, lineWidth: 1.5)
                    } else if dayKey == todayKey {
                        Circle().strokeBorder(.tint.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isPlayable)
        .accessibilityLabel(Text(DayKeyFormat.string(dayKey, date: .long)))
        .accessibilityValue(accessibilityStatus)
    }

    private var foreground: AnyShapeStyle {
        if record?.isCompleted == true { return AnyShapeStyle(.background) }
        if dayKey == todayKey { return AnyShapeStyle(.tint) }
        return isPlayable ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
    }

    private var accessibilityStatus: Text {
        if record?.isCompleted == true { return Text("Completed") }
        if record?.isFinished == true { return Text("Played") }
        return Text(verbatim: "")
    }
}
