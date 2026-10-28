import QuietCore
import QuietNumbersCore
import QuietUI
import SwiftUI

/// Month grid of daily challenges. Completed days are filled, played ones outlined, past
/// days cleared as practice softly tinted, a dot marks a game left halfway, and days completed
/// in a row are joined by a band (within a week). Days within the replay window can be tapped
/// to play them unscored.
struct CalendarView: View {
    @Binding var month: Date
    let todayKey: String
    let records: [String: DailyRecord]
    let practiced: Set<String>
    let inProgress: Set<String>
    let onSelect: (String) -> Void

    @Environment(\.quietTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.backward")
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(theme.primary)
                .accessibilityLabel(Text("Previous month"))
                Spacer()
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Spacer()
                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.forward")
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(isCurrentMonth ? theme.ghost : theme.primary)
                .disabled(isCurrentMonth)
                .accessibilityLabel(Text("Next month"))
            }
            .font(.subheadline.weight(.bold))
            .buttonStyle(.plain)

            LazyVGrid(columns: columns, spacing: 0) {
                // One ForEach with distinct ids: sibling ForEach ids collide inside a grid.
                ForEach(items, id: \.self) { item in
                    switch item {
                    case .weekday(let index):
                        Text(weekdaySymbols[index])
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 6)
                    case .blank:
                        Color.clear.frame(height: 1)
                    case .day(let day):
                        let column = (leadingBlanks + day - 1) % 7
                        DayCell(
                            day: day,
                            dayKey: dayKey(for: day),
                            todayKey: todayKey,
                            record: records[dayKey(for: day)],
                            isPracticed: practiced.contains(dayKey(for: day)),
                            isInProgress: inProgress.contains(dayKey(for: day)),
                            isPlayable: isPlayable(dayKey(for: day)),
                            joinsPrevious: column != 0 && isCompleted(day) && isCompleted(day - 1),
                            joinsNext: column != 6 && isCompleted(day) && isCompleted(day + 1),
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
        calendar.isDate(month, equalTo: AppClock.now, toGranularity: .month)
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

    private func isCompleted(_ day: Int) -> Bool {
        days.contains(day) && records[dayKey(for: day)]?.isCompleted == true
    }

    private func isPlayable(_ key: String) -> Bool {
        guard let oldest = DailyKey.dayKey(todayKey, addingDays: -DailyKey.replayWindow) else { return false }
        return key <= todayKey && key >= oldest
    }
}

private struct DayCell: View {
    let day: Int
    let dayKey: String
    let todayKey: String
    let record: DailyRecord?
    /// Cleared later as practice; a day completed on time keeps its own look.
    let isPracticed: Bool
    /// A game on this day was left halfway.
    let isInProgress: Bool
    let isPlayable: Bool
    /// Completed, like the day before (or after) in the same week: the band reaches it.
    let joinsPrevious: Bool
    let joinsNext: Bool
    let onSelect: (String) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.quietTheme) private var theme

    var body: some View {
        let isRegular = sizeClass == .regular
        let height: CGFloat = isRegular ? 56 : 42
        let circle = height - 6
        Button {
            onSelect(dayKey)
        } label: {
            Text(day, format: .number)
                .font(.system(isRegular ? .title3 : .callout, design: .rounded, weight: record?.isCompleted == true || isPracticed || isToday ? .bold : .regular).monospacedDigit())
                .foregroundStyle(foreground)
                .frame(width: circle, height: circle)
                .background {
                    if record?.isCompleted == true {
                        Circle().fill(theme.primary)
                    } else if isPracticed {
                        Circle().fill(theme.primary.opacity(0.22))
                    } else if record?.isFinished == true {
                        Circle().strokeBorder(theme.primary, lineWidth: 1.5)
                    }
                }
                .overlay {
                    if isToday {
                        Circle()
                            .strokeBorder(theme.accent, lineWidth: 2)
                            .padding(-4)
                    }
                }
                .overlay(alignment: .bottom) {
                    if isInProgress {
                        Circle()
                            .fill(record?.isCompleted == true ? theme.onPrimary : theme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.bottom, isRegular ? 7 : 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background { band(height: circle) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isPlayable)
        .accessibilityLabel(Text(DayKeyFormat.string(dayKey, date: .long)))
        .accessibilityValue(accessibilityStatus)
    }

    private var isToday: Bool { dayKey == todayKey }

    /// 20% `primary` behind the circles, from this day's center to the neighbor it joins.
    @ViewBuilder
    private func band(height: CGFloat) -> some View {
        if joinsPrevious || joinsNext {
            GeometryReader { geometry in
                let mid = geometry.size.width / 2
                let start = joinsPrevious ? 0 : mid
                let end = joinsNext ? geometry.size.width : mid
                Rectangle()
                    .fill(theme.primary.opacity(0.2))
                    .frame(width: end - start, height: height)
                    .offset(x: start, y: (geometry.size.height - height) / 2)
            }
        }
    }

    private var foreground: Color {
        if record?.isCompleted == true { return theme.onPrimary }
        if isToday { return theme.accent }
        if isPracticed { return theme.primary }
        return isPlayable ? theme.ink : theme.muted.opacity(0.6)
    }

    private var accessibilityStatus: Text {
        if isInProgress { return Text("In progress") }
        if record?.isCompleted == true { return Text("Completed") }
        if isPracticed { return Text("Practiced") }
        if record?.isFinished == true { return Text("Played") }
        return Text(verbatim: "")
    }
}
