import Domain
import SwiftUI

/// One logged day (HISTORY_SPEC §4). The date, the day's calories against that
/// day's target, how far off it landed, and up to three of the meals by name.
///
/// The card is **one** button. §4 is explicit about it: chips are not separate tap
/// targets, so a 38pt chip can never steal a tap meant for the day, and the way to
/// a single meal is day panel first. That is also what lets the whole card be one
/// accessibility element (§7) instead of eleven.
///
/// Replaces `HistoryDayRow`, which was the same idea with a thumbnail and a
/// one-line summary. What it could not do was answer "was that a heavy day" — the
/// figure was there but nothing to read it against, which is what the deviation bar
/// adds and what §1c of the design exploration was arguing for.
struct HistoryDayCard: View {
    let day: HistoryDay
    /// That day's target. See `HistoryMonthsModel.dailyGoalCalories` for why this
    /// is today's target rather than the one in force on the day (§8's one
    /// unmet requirement).
    let goalCalories: Double
    let isToday: Bool
    let onSelect: () -> Void

    /// §4's threshold: from `.accessibility1` the date stops being a column beside
    /// the figures and becomes a line above them.
    @Environment(\.dynamicTypeSize) private var typeSize

    /// How many meals are named on the card before the rest become "+N món".
    static let visibleChipCount = 3
    private static let dayColumnWidth: CGFloat = 42

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 11) {
                // Measured rather than switched on the type size: the column only
                // has to move when the figures beside it no longer fit, and
                // `ViewThatFits` asks exactly that question (§4). The fallback —
                // the stacked layout — is last, so it is what a size nothing fits
                // at lands on.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: DS.s3) {
                        dayColumn
                            .frame(width: Self.dayColumnWidth)
                        figures
                    }
                    VStack(alignment: .leading, spacing: DS.s2) {
                        dayRow
                        figures
                    }
                }
                if !day.meals.isEmpty {
                    MealChipRow(meals: day.meals)
                }
            }
            .padding(13)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.rCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.rCard, style: .continuous)
                    .strokeBorder(DS.borderSubtle, lineWidth: 1)
            }
            // Without this the card only hit-tests where glyphs are drawn, so the
            // space around the chips is dead — the case CLAUDE.md records.
            .contentShape(RoundedRectangle(cornerRadius: DS.rCard, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Chạm hai lần để xem các bữa trong ngày.")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("history.day.\(HistoryCalendar.identifier(for: day.date))")
    }

    // MARK: The date

    private var dayColumn: some View {
        VStack(spacing: 1) {
            Text(VietnameseDate.dayNumber(for: day.date))
                .font(.custom(DSFontName.bold, size: 20))
                .monospacedDigit()
                .foregroundStyle(isToday ? DS.blueOnSurface : DS.textStrong)
            Text(VietnameseDate.weekdayCompact(for: day.date))
                .font(.custom(DSFontName.semibold, size: 10.5))
                .foregroundStyle(DS.textMuted)
            if isToday {
                // §4 wants this beside the weekday, and the column is 42pt wide so
                // every card's figures line up. It gets the width it can have and
                // shrinks rather than pushing the column wider for one card.
                Text("Hôm nay")
                    .font(.custom(DSFontName.semibold, size: 9.5))
                    .foregroundStyle(DS.blueOnSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .multilineTextAlignment(.center)
    }

    /// The same information as a line, for when the column no longer fits.
    private var dayRow: some View {
        HStack(spacing: 6) {
            Text(VietnameseDate.dayNumber(for: day.date))
                .font(.custom(DSFontName.bold, size: 20))
                .monospacedDigit()
                .foregroundStyle(isToday ? DS.blueOnSurface : DS.textStrong)
            // `verbatim`, or the separator becomes a key in the catalog for a
            // translator to wonder about.
            Text(verbatim: "·")
                .font(.custom(DSFontName.semibold, size: 10.5))
                .foregroundStyle(DS.axis)
            Text(VietnameseDate.weekdayCompact(for: day.date))
                .font(.custom(DSFontName.semibold, size: 10.5))
                .foregroundStyle(DS.textMuted)
            if isToday {
                Text("Hôm nay")
                    .font(.custom(DSFontName.semibold, size: 10.5))
                    .foregroundStyle(DS.blueOnSurface)
            }
        }
    }

    // MARK: The figures

    private var figures: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(VNNumber.int(day.calories))
                    .font(.custom(DSFontName.bold, size: 17))
                    .monospacedDigit()
                    .foregroundStyle(DS.textStrong)
                    .lineLimit(1)
                Text(goalText)
                    .font(.custom(DSFontName.medium, size: 12))
                    .foregroundStyle(DS.textMuted)
                    // Wraps rather than truncates: at a large text size the target
                    // is the first thing that runs out of room, and it is half of
                    // what the bar underneath means.
                    .lineLimit(2)
            }
            HistoryDeviationBar(calories: day.calories, goalCalories: goalCalories)
                .padding(.top, DS.s2)
            Text(deltaText)
                .font(.custom(DSFontName.medium, size: 11.5))
                .foregroundStyle(DS.textMuted)
                .padding(.top, 6)
        }
    }

    private var goalText: String {
        goalCalories > 0
            ? String(localized: "kcal · mục tiêu \(VNNumber.int(goalCalories))")
            : String(localized: "kcal")
    }

    /// §4's three cases. Never a command and never a judgement — "Vượt 180 kcal" is
    /// a measurement, which is the whole of §0.3.
    private var deltaText: String {
        let mealCount = day.meals.count
        guard goalCalories > 0 else {
            return String(localized: "\(mealCount) bữa")
        }
        let difference = day.calories - goalCalories
        if abs(difference) <= goalCalories * Self.onTargetTolerance {
            return String(localized: "Đạt mục tiêu · \(mealCount) bữa")
        }
        if difference > 0 {
            return String(localized: "Vượt \(VNNumber.int(difference)) kcal · \(mealCount) bữa")
        }
        return String(localized: "Còn \(VNNumber.int(-difference)) kcal · \(mealCount) bữa")
    }

    /// §4: within 2% of the target reads as having hit it. Without a tolerance,
    /// "Vượt 5 kcal" would be the copy on a day that was, for any purpose the user
    /// has, exactly on target.
    private static let onTargetTolerance = 0.02

    // MARK: VoiceOver

    /// §7's label, in its order: the date spelled out, the figure against the
    /// target, how far off, the meals by name, then whether there are photos.
    private var accessibilityLabel: String {
        var parts: [String] = [VietnameseDate.spokenDayText(for: day.date) + "."]

        if goalCalories > 0 {
            parts.append(
                String(
                    localized:
                        "\(VNNumber.int(day.calories)) ki-lô ca-lo trên mục tiêu \(VNNumber.int(goalCalories))."
                )
            )
            let difference = day.calories - goalCalories
            if abs(difference) <= goalCalories * Self.onTargetTolerance {
                parts.append(String(localized: "Đạt mục tiêu."))
            } else if difference > 0 {
                parts.append(String(localized: "Vượt \(VNNumber.int(difference))."))
            } else {
                parts.append(String(localized: "Còn \(VNNumber.int(-difference))."))
            }
        } else {
            parts.append(String(localized: "\(VNNumber.int(day.calories)) ki-lô ca-lo."))
        }

        // Every meal, not only the three the card has room to draw: the chips are
        // a summary because the card is narrow, which is not a constraint VoiceOver
        // shares.
        let names = day.meals.map(HistoryDayCard.chipName(for:))
        if !names.isEmpty {
            parts.append(
                String(localized: "\(names.count) bữa: \(names.joined(separator: ", ")).")
            )
        }
        if day.photoCount > 0 {
            parts.append(String(localized: "Có \(day.photoCount) ảnh."))
        }
        return parts.joined(separator: " ")
    }

    /// What one meal is called on a chip: its first dish, plus a count when there
    /// was more than one thing in it.
    ///
    /// A meal with nothing in it cannot happen through the UI, but a chip with an
    /// empty name could, so it falls back to the meal's own name.
    static func chipName(for meal: Meal) -> String {
        guard let first = meal.items.first?.name, !first.isEmpty else { return meal.type.vi }
        guard meal.items.count > 1 else { return first }
        return "\(first) +\(meal.items.count - 1)"
    }
}

/// The card's row of meal chips: three at most, then "+N món".
///
/// It **wraps**, which is how the design draws it (`flex-wrap`) and also how §4's
/// "`HStack` → `VStack` from `.accessibility1`" arrives on its own — a chip wider
/// than the card takes a line to itself, so the row becomes a column at exactly the
/// size where a row stops working, with no threshold to keep in step with the
/// figures above.
struct MealChipRow: View {
    let meals: [Meal]

    private var shown: [Meal] {
        Array(meals.prefix(HistoryDayCard.visibleChipCount))
    }

    private var overflow: Int {
        max(meals.count - HistoryDayCard.visibleChipCount, 0)
    }

    var body: some View {
        WrapLayout(spacing: DS.s2, lineSpacing: DS.s2) {
            ForEach(shown) { meal in
                MealChip(
                    name: HistoryDayCard.chipName(for: meal),
                    meta: chipMeta(for: meal),
                    photoID: meal.photos.first?.id
                )
            }
            if overflow > 0 {
                MealChipMore(count: overflow)
            }
        }
    }

    /// "06:50 · 480 kcal".
    private func chipMeta(for meal: Meal) -> String {
        "\(VietnameseDate.time(for: meal.date)) · \(VNNumber.int(meal.calories)) kcal"
    }
}

/// Left-to-right flow: as many subviews per line as fit, then the next line.
///
/// SwiftUI has no wrapping stack, and the two ways round it both fail here — a
/// `LazyVGrid` gives every cell the same width, which a row of dish names is not,
/// and `ViewThatFits` between an `HStack` and a `VStack` can only ever choose all
/// on one line or all on their own.
private struct WrapLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let lines = layout(subviews: subviews, in: width)
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(lines.count - 1, 0))
        // The proposed width, not the widest line: the card is full width and a
        // shorter answer would let the row centre itself inside it.
        return CGSize(width: proposal.width ?? lines.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var y = bounds.minY
        for line in layout(subviews: subviews, in: bounds.width) {
            var x = bounds.minX
            for item in line.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Item {
        let index: Int
        let size: CGSize
    }

    private struct Line {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Each subview is offered the full line width, so one too wide for a line
    /// wraps its own text instead of overflowing the card.
    private func layout(subviews: Subviews, in width: CGFloat) -> [Line] {
        var lines: [Line] = []
        var current = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(
                ProposedViewSize(width: width, height: nil)
            )
            let needed = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if !current.items.isEmpty, needed > width {
                lines.append(current)
                current = Line()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append(Item(index: index, size: size))
        }
        if !current.items.isEmpty { lines.append(current) }
        return lines
    }
}

#if DEBUG
    /// §9 step 2 asks for all five: one photo, several photos, no photo, today, and
    /// over target.
    #Preview("Day cards") {
        ScrollView {
            VStack(spacing: 10) {
                HistoryDayCard(
                    day: HistoryPreviewData.dayWithOnePhoto,
                    goalCalories: 1_900,
                    isToday: false,
                    onSelect: {}
                )
                HistoryDayCard(
                    day: HistoryPreviewData.dayWithSeveralPhotos,
                    goalCalories: 1_900,
                    isToday: false,
                    onSelect: {}
                )
                HistoryDayCard(
                    day: HistoryPreviewData.dayWithoutPhotos,
                    goalCalories: 1_900,
                    isToday: false,
                    onSelect: {}
                )
                HistoryDayCard(
                    day: HistoryPreviewData.today,
                    goalCalories: 1_900,
                    isToday: true,
                    onSelect: {}
                )
                HistoryDayCard(
                    day: HistoryPreviewData.dayOverBudget,
                    goalCalories: 1_900,
                    isToday: false,
                    onSelect: {}
                )
            }
            .padding(DS.s4)
        }
        .background(DS.surfacePage)
        .environment(DependencyContainer(inMemory: true))
    }

    #Preview("Day card · accessibility3") {
        ScrollView {
            VStack(spacing: 10) {
                HistoryDayCard(
                    day: HistoryPreviewData.today,
                    goalCalories: 1_900,
                    isToday: true,
                    onSelect: {}
                )
                HistoryDayCard(
                    day: HistoryPreviewData.dayOverBudget,
                    goalCalories: 1_900,
                    isToday: false,
                    onSelect: {}
                )
            }
            .padding(DS.s4)
        }
        .background(DS.surfacePage)
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(DependencyContainer(inMemory: true))
    }
#endif
