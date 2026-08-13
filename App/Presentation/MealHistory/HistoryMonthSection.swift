import Domain
import SwiftUI

/// One month of the history list: a header, then a row per day something was
/// logged on (§32.2, revised — see `HistoryDayRow`).
///
/// A month with nothing in it is never built; `HistoryMonthsModel.visibleMonths`
/// drops it, so scrolling back never lands on a section of empty dates.
struct HistoryMonthSection: View {
    let month: HistoryMonth
    let today: Date
    let onSelect: (HistoryDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            header
            // Not `HFCard`, and the difference is measured rather than aesthetic.
            //
            // A month of logged days is a card over a thousand points tall, and
            // `HFCard` puts **two shadows** on it — §9's shadow is drawn for small
            // blocks, and blurring this one costs a full offscreen pass of the
            // whole card every time the list moves. A `sample` of the app during a
            // scroll showed the main thread ~45% busy inside SwiftUI's lazy layout,
            // which is enough that the app never goes idle and XCUITest's
            // accessibility queries time out at 30s.
            //
            // Same surface, same border, same radius. No shadow.
            VStack(spacing: 0) {
                ForEach(Array(month.days.enumerated()), id: \.element.id) { index, day in
                    HistoryDayRow(
                        day: day,
                        isToday: day.date == today,
                        onSelect: { onSelect(day) }
                    )
                    if index < month.days.count - 1 {
                        Rectangle().fill(DS.borderSubtle)
                            .frame(height: 1)
                            // Starts past the thumbnail, so the rows read as one
                            // list rather than separate cards.
                            .padding(.leading, HistoryDayRow.thumbnailSide + DS.s4 + DS.s3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.rCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.rCard, style: .continuous)
                    .strokeBorder(DS.borderSubtle, lineWidth: 1)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
            Text(title)
                .font(.custom(DSFontName.bold, size: 11.5))
                .tracking(0.8)
                .foregroundStyle(DS.textMuted)
            Spacer(minLength: DS.s2)
            Text(subtitle)
                .font(.custom(DSFontName.regular, size: 11.5))
                .foregroundStyle(DS.textSubtle)
        }
        .padding(.horizontal, DS.s1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isStaticText)
        // On the header, **not** on the section that contains the rows: an
        // identifier set on a container propagates down and overrides the ones the
        // rows set for themselves, so every row came out as
        // `history.month.<id>` and `history.day.<date>` existed nowhere. The
        // labels were right the whole time, which is what made it puzzling.
        .accessibilityIdentifier("history.month.\(month.id)")
    }

    /// "THÁNG 8, 2026" — a section label rather than a card title now, so it is
    /// set in caps at the small step. The month is one month by construction, so
    /// both ends of `monthText` are the same day.
    private var title: String {
        guard let first = month.days.first?.date else { return "" }
        return VietnameseDate.monthText(from: first, to: first).uppercased()
    }

    /// Neutral and factual: how much of the month is on the record, never a score
    /// (§4 — this is not a streak).
    private var subtitle: String {
        String(localized: "\(month.days.count) ngày · \(VNNumber.int(month.calories)) kcal")
    }
}
