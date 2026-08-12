import SwiftUI

/// The week picker above the history list: seven day columns, a dot under every
/// day that has meals logged, and arrows to page a week at a time.
///
/// Not in the handoff — §6.11 draws a plain scroll of day sections. It picks the
/// one day the screen shows.
struct HistoryWeekStrip: View {
    let week: [MealHistoryModel.DayCell]
    let selectedDate: Date
    let canGoForward: Bool
    let onSelect: (Date) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            HStack(spacing: 0) {
                Text(monthText)
                    .font(.custom(DSFontName.semibold, size: 12.5))
                    .foregroundStyle(DS.textMuted)
                Spacer(minLength: DS.s2)
                arrow(systemName: "chevron.left", identifier: "history.week.previous", action: onPrevious)
                arrow(
                    systemName: "chevron.right",
                    identifier: "history.week.next",
                    enabled: canGoForward,
                    action: onNext
                )
            }

            HStack(spacing: DS.s1) {
                ForEach(week) { cell in
                    dayCell(cell)
                }
            }
        }
    }

    private var monthText: String {
        guard let first = week.first?.date, let last = week.last?.date else { return "" }
        return VietnameseDate.monthText(from: first, to: last)
    }

    private func arrow(
        systemName: String,
        identifier: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? DS.textBody : DS.neutral300)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }

    private func dayCell(_ cell: MealHistoryModel.DayCell) -> some View {
        let isSelected = cell.date == selectedDate
        return Button {
            onSelect(cell.date)
        } label: {
            VStack(spacing: 3) {
                Text(VietnameseDate.weekdayShort(for: cell.date))
                    .font(.custom(DSFontName.semibold, size: 10.5))
                    .foregroundStyle(isSelected ? DS.blue700 : DS.textSubtle)
                Text(VietnameseDate.dayNumber(for: cell.date))
                    .font(.custom(DSFontName.bold, size: 15))
                    .foregroundStyle(numberColor(cell, isSelected: isSelected))
                Circle()
                    .fill(cell.hasMeals ? DS.blue : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(
                isSelected ? DS.blue50 : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                    .strokeBorder(
                        isSelected ? DS.blue : DS.borderSubtle,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            // The glyphs are narrow columns of text, so without this the cell
            // answers only where they are drawn — the case CLAUDE.md records.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cell.isFuture)
        .opacity(cell.isFuture ? 0.4 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(cell))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("history.day.\(Self.identifier(for: cell.date))")
    }

    private func numberColor(_ cell: MealHistoryModel.DayCell, isSelected: Bool) -> Color {
        if isSelected { return DS.blue700 }
        // Today keeps a mark of its own once the selection has moved off it.
        return cell.isToday ? DS.blueOnSurface : DS.textStrong
    }

    private func accessibilityLabel(_ cell: MealHistoryModel.DayCell) -> String {
        let day = VietnameseDate.dayText(for: cell.date)
        if cell.isFuture { return String(localized: "\(day), chưa tới") }
        return cell.hasMeals
            ? String(localized: "\(day), có bữa ăn đã ghi")
            : String(localized: "\(day), chưa ghi bữa nào")
    }

    /// A stable, locale-independent identifier so a UI test can name a day.
    ///
    /// Built from date components rather than a `DateFormatter`: this runs once
    /// per cell per render, and a formatter is expensive to construct — which it
    /// would have to be every time, being neither `Sendable` nor cacheable in a
    /// `static let` under strict concurrency.
    static func identifier(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
