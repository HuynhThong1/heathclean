import Domain
import SwiftUI

/// One month of history: a header, then a card per day something was logged on
/// (HISTORY_SPEC §1, §2).
///
/// A month with nothing in it is never a section — `HistoryMonthsModel.feed` turns
/// it into `EmptyMonthDivider`, one line rather than a card of empty dates. §0.1 is
/// the rule behind both: a day with no data does not exist in the UI.
struct HistoryMonthSection: View {
    let month: HistoryMonth
    /// The current target, used only for a day that recorded none of its own — see
    /// `HistoryDay.goalCalories(fallingBackTo:)`. Each card is drawn against *its*
    /// day's target (§8), so this is not simply "the goal".
    let fallbackGoalCalories: Double
    let today: Date
    let onSelect: (HistoryDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonthHeader(month: month)
            VStack(spacing: 10) {
                ForEach(month.days) { day in
                    HistoryDayCard(
                        day: day,
                        goalCalories: day.goalCalories(fallingBackTo: fallbackGoalCalories),
                        isToday: day.date == today,
                        onSelect: { onSelect(day) }
                    )
                }
            }
        }
    }
}

/// "Tháng 8, 2026" with the month's shape on the right: how many days are on the
/// record and what they averaged (§2, §8).
struct MonthHeader: View {
    let month: HistoryMonth

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.s3) {
            Text(title)
                .font(.custom(DSFontName.bold, size: 15))
                .foregroundStyle(DS.textStrong)
            Spacer(minLength: DS.s2)
            Text(meta)
                .font(.custom(DSFontName.regular, size: 11.5))
                .foregroundStyle(DS.textMuted)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, DS.s1)
        .padding(.top, DS.s3)
        .padding(.bottom, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(meta)")
        .accessibilityAddTraits(.isHeader)
        // On the header, **not** on the section around the cards: an identifier on a
        // container propagates down and overrides the ones the cards set, which once
        // made every day come out as `history.month.<id>`.
        .accessibilityIdentifier("history.month.\(month.id)")
    }

    private var title: String {
        AppDate.monthYearText(year: month.year, month: month.month)
    }

    /// "5 ngày ghi · TB 1.780 kcal".
    ///
    /// The average is over **logged days only** (§8) — dividing by the length of the
    /// month would report a number the user never ate, and would make a month with
    /// one good day look like a starvation month.
    private var meta: String {
        let count = month.days.count
        guard count > 0 else { return L("chưa ghi ngày nào") }
        let average = month.calories / Double(count)
        return L("\(count) ngày ghi · TB \(AppNumber.int(average)) kcal")
    }
}

/// "Tháng 7, 2026 — chưa ghi ngày nào" between two rules (§2, §6).
///
/// A month with nothing in it still has to appear, or scrolling back would silently
/// skip time and the run of dates would read as continuous when it is not. One 28pt
/// line is what that costs. §7: it reads as text, never as a button — there is
/// nothing behind it, because MVP cannot back-date a meal.
struct EmptyMonthDivider: View {
    let year: Int
    let month: Int

    var body: some View {
        HStack(spacing: 10) {
            rule
            Text(text)
                .font(.custom(DSFontName.regular, size: 11.5))
                // §2 draws this in #94A3B2, which is about 3.2:1 on the page. §7 is
                // the rule that wins: a small grey on `pageBg` has to carry its
                // contrast, so it takes `textMuted` (5.6:1). Between two hairlines it
                // still reads as the quietest thing on the screen.
                .foregroundStyle(DS.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                // Without this the two greedy rules split the width three ways and
                // the line wraps at the em dash even though it fits. It keeps its
                // ideal width when there is room and still wraps when there is not,
                // which `fixedSize` would not.
                .layoutPriority(1)
            rule
        }
        .frame(minHeight: 28)
        .padding(.horizontal, DS.s1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("history.emptyMonth.\(String(format: "%04d-%02d", year, month))")
    }

    private var rule: some View {
        Rectangle()
            .fill(DS.borderDefault)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private var text: String {
        L("\(AppDate.monthYearText(year: year, month: month)) — chưa ghi ngày nào")
    }
}

#if DEBUG
    #Preview("Month section") {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HistoryMonthSection(
                    month: HistoryPreviewData.month,
                    fallbackGoalCalories: HistoryPreviewData.goalCalories,
                    today: HistoryPreviewData.today.date,
                    onSelect: { _ in }
                )
                EmptyMonthDivider(
                    year: HistoryPreviewData.emptyMonth.year,
                    month: HistoryPreviewData.emptyMonth.month
                )
                .padding(.vertical, 6)
            }
            .padding(.horizontal, DS.s4)
        }
        .background(DS.surfacePage)
        .environment(DependencyContainer(inMemory: true))
    }
#endif
