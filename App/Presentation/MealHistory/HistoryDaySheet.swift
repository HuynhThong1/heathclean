import Domain
import SwiftUI

/// One day of history, opened by tapping a cell of the month grid (§32.2 item 3).
///
/// It is how the grid reaches meals at all, so it exists from stage 1 with the
/// day's totals and its meals in time order. §32.3's skeleton, retry state and
/// multi-photo badge are stage 3.
struct HistoryDaySheet: View {
    let day: HistoryDay
    let goalCalories: Double
    /// A meal was edited: the grid behind has to re-read.
    let onChanged: () -> Void
    /// A whole meal was deleted. The sheet closes, because the parent owns the
    /// toast and a toast cannot be shown from behind a sheet.
    let onDeleted: () -> Void

    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var route: MealType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.s4) {
                    photos
                    summaryCard
                    if day.meals.isEmpty {
                        GrayNote(text: emptyText)
                    } else {
                        mealsCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, DS.s3)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(DS.surfacePage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.vertical, DS.s3)
                    .background(DS.surfacePage)
            }
            .navigationDestination(item: $route) { type in
                MealDetailRoute(
                    type: type,
                    meals: day.meals(of: type),
                    dailyGoalCalories: goalCalories,
                    // History is a record, not a place to keep eating from —
                    // adding more belongs to today, which the dashboard owns.
                    onAddMore: { route = nil },
                    onChanged: onChanged,
                    onDeleted: {
                        route = nil
                        onDeleted()
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Colour the sheet, not the content: a detent taller than the content
        // otherwise leaves the sheet's own backing showing, which is a black band
        // in dark mode.
        .presentationBackground(DS.surfacePage)
        .accessibilityIdentifier("history.day.sheet")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
            Text(VietnameseDate.dayText(for: day.date))
                .font(.custom(DSFontName.extrabold, size: 21))
                .tracking(-0.4)
                .foregroundStyle(DS.textStrong)
            Spacer(minLength: DS.s2)
            Button {
                dismiss()
            } label: {
                Text("Đóng")
                    .font(.custom(DSFontName.semibold, size: 14.5))
                    .foregroundStyle(DS.blueOnSurface)
                    .padding(.horizontal, DS.s2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("history.day.close")
        }
    }

    /// The day's pictures. Layout and loading live in `MealPhotoGrid`, shared with
    /// the meal detail screen so there is one rule rather than two.
    private var photos: some View {
        MealPhotoGrid(photos: day.photos, identifierPrefix: "history.day.sheet.photo")
    }

    private var summaryCard: some View {
        HFCard {
            VStack(alignment: .leading, spacing: DS.s3) {
                HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
                    Text("\(VNNumber.int(day.calories)) kcal")
                        .font(.custom(DSFontName.extrabold, size: 24))
                        .foregroundStyle(DS.textStrong)
                    if goalCalories > 0 {
                        Text("/ \(VNNumber.int(goalCalories)) kcal")
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(DS.textSubtle)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(caloriesLabel)
                .accessibilityAddTraits(.isStaticText)

                progressBar

                HStack(spacing: DS.s2) {
                    MacroChip(
                        vi: "Đạm",
                        grams: day.protein,
                        background: DS.blue50,
                        foreground: DS.blue700
                    )
                    MacroChip(
                        vi: "Tinh bột",
                        grams: day.carbohydrates,
                        background: DS.orange100,
                        foreground: DS.orange700
                    )
                    MacroChip(
                        vi: "Chất béo",
                        grams: day.fat,
                        background: DS.green100,
                        foreground: DS.green700
                    )
                }
            }
        }
    }

    /// Blue under goal, neutral over — the same non-alarming treatment as the
    /// dashboard ring and the week strip's day bar (§4).
    private var progressBar: some View {
        let fraction = goalCalories > 0 ? min(day.calories / goalCalories, 1) : 0
        let isOver = goalCalories > 0 && day.calories > goalCalories
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(DS.neutral150)
                Capsule()
                    .fill(isOver ? DS.danger : DS.blue)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private var mealsCard: some View {
        HFCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(day.meals.enumerated()), id: \.element.id) { index, meal in
                    mealRow(meal)
                    if index < day.meals.count - 1 {
                        Rectangle().fill(DS.borderSubtle)
                            .frame(height: 1)
                            .padding(.leading, 54)
                    }
                }
            }
        }
    }

    private func mealRow(_ meal: Meal) -> some View {
        Button {
            route = meal.type
        } label: {
            HStack(spacing: DS.s3) {
                Image(systemName: meal.type.chipSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.textBody)
                    .frame(width: 28, height: 28)
                    .background(
                        meal.type.chipColor,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(meal.type.vi)
                        .font(.custom(DSFontName.semibold, size: 13.5))
                        .foregroundStyle(DS.textStrong)
                    Text(meal.items.map(\.name).joined(separator: ", "))
                        .font(.custom(DSFontName.regular, size: 11))
                        .foregroundStyle(DS.textSubtle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: DS.s2)

                Text("\(VNNumber.int(meal.calories)) kcal")
                    .font(.custom(DSFontName.bold, size: 13))
                    .foregroundStyle(DS.textStrong)
            }
            .padding(.horizontal, DS.s4)
            .frame(minHeight: 54)
            // Without this the row only hit-tests where text is drawn, so the gap
            // between the name and the kcal figure is dead space.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(meal.type.vi), \(VNNumber.int(meal.calories)) kcal")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("history.meal.\(meal.type.rawValue)")
    }

    private var caloriesLabel: String {
        guard goalCalories > 0 else {
            return String(localized: "\(VNNumber.int(day.calories)) kcal đã ghi")
        }
        return String(
            localized: "\(VNNumber.int(day.calories)) trên \(VNNumber.int(goalCalories)) kcal"
        )
    }

    private var emptyText: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar.isDateInToday(day.date)
            ? String(localized: "Hôm nay chưa ghi bữa nào. Những bữa bạn ghi sẽ xuất hiện ở đây.")
            : String(localized: "Ngày này không có bữa ăn nào được ghi.")
    }
}
