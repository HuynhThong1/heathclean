import Domain
import SwiftUI

/// One day, opened by tapping its card (HISTORY_SPEC §6's "Day panel").
///
/// It is the only way from History into a meal, which §4 chose deliberately: the
/// chips on a card are not buttons, so the day is always the step in between. That
/// makes this sheet the place the day's *figures* live — the total against the
/// target, how far off it landed, the three macros — and the meal list underneath is
/// the way further in.
///
/// **No photo grid, unlike the sheet this replaces.** §6 enumerates what the panel
/// holds and a picture at size is not in it; each meal row carries a 34pt thumbnail
/// instead, and `MealDetailView` one tap deeper still shows the photos full width.
/// The version that opened with a 150pt photo pushed the calorie total below the
/// detent on a small phone — the numbers are what this sheet is *for*.
struct HistoryDayPanelSheet: View {
    let day: HistoryDay
    /// Calories for the bar, macros for the three cells. `nil` before the profile
    /// loads, which is a state the sheet can be opened in.
    let goal: NutritionGoal?
    let isToday: Bool
    /// A meal was edited: the list behind has to re-read.
    let onChanged: () -> Void
    /// A whole meal was deleted. The sheet closes, because the parent owns the toast
    /// and a toast cannot be shown from behind a sheet.
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var route: MealType?

    private var goalCalories: Double { goal?.calories ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    totals
                        .padding(.top, 14)
                    if let goal {
                        macros(goal)
                            .padding(.top, DS.s4)
                    }
                    if day.meals.isEmpty {
                        // Reachable through a stale selection: the day was open when
                        // its last meal was deleted from the detail screen.
                        GrayNote(text: "Ngày này không có bữa ăn nào được ghi.")
                            .padding(.top, 18)
                    } else {
                        mealList
                            .padding(.top, 18)
                    }
                }
                .padding(.horizontal, DS.s4)
                .padding(.top, DS.s2)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(DS.surfaceCard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $route) { type in
                MealDetailRoute(
                    type: type,
                    meals: day.meals(of: type),
                    dailyGoalCalories: goalCalories,
                    // History is a record, not a place to keep eating from — adding
                    // more belongs to today, which the dashboard owns.
                    onAddMore: { route = nil },
                    onChanged: onChanged,
                    onDeleted: {
                        route = nil
                        onDeleted()
                    }
                )
            }
        }
        .presentationDetents([.fraction(0.78), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        // Colour the *sheet*, not the content: a detent taller than the content
        // otherwise leaves the sheet's own backing showing, which is a black band in
        // dark mode. The panel is the card surface because its rows are drawn
        // directly on it, divided by hairlines rather than boxed into cards.
        .presentationBackground(DS.surfaceCard)
        .accessibilityIdentifier("history.day.sheet")
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: DS.s2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(VietnameseDate.fullDayText(for: day.date))
                    .font(.custom(DSFontName.bold, size: 18))
                    .foregroundStyle(DS.textStrong)
                if isToday {
                    Text("Hôm nay · Today")
                        .font(.custom(DSFontName.regular, size: 11.5))
                        .foregroundStyle(DS.textMuted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            // The drag indicator is the design's only way out, and it is not a
            // control VoiceOver or a first-time user can find. Every screen in this
            // app that draws its own header supplies its own way back.
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

    // MARK: Totals

    private var totals: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(VNNumber.int(day.calories))
                    .font(.custom(DSFontName.bold, size: 30))
                    .tracking(-0.3)
                    .monospacedDigit()
                    .foregroundStyle(DS.textStrong)
                Text(goalText)
                    .font(.custom(DSFontName.medium, size: 13))
                    .foregroundStyle(DS.textMuted)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(caloriesLabel)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("history.day.total")

            HistoryDeviationBar(calories: day.calories, goalCalories: goalCalories, height: 10)
                .padding(.top, 10)

            Text(deltaText)
                .font(.custom(DSFontName.medium, size: 11.5))
                .foregroundStyle(DS.textMuted)
                .padding(.top, 7)
        }
    }

    private var goalText: String {
        goalCalories > 0
            ? String(localized: "kcal / mục tiêu \(VNNumber.int(goalCalories))")
            : String(localized: "kcal")
    }

    private var caloriesLabel: String {
        guard goalCalories > 0 else {
            return String(localized: "\(VNNumber.int(day.calories)) ki-lô ca-lo đã ghi")
        }
        return String(
            localized:
                "\(VNNumber.int(day.calories)) ki-lô ca-lo trên mục tiêu \(VNNumber.int(goalCalories))"
        )
    }

    /// The card's copy, said again here because this is where the day is read in
    /// detail. §0.3: a measurement, never an instruction.
    private var deltaText: String {
        let mealCount = day.meals.count
        guard goalCalories > 0 else { return String(localized: "\(mealCount) bữa") }
        let difference = day.calories - goalCalories
        if abs(difference) <= goalCalories * 0.02 {
            return String(localized: "Đạt mục tiêu · \(mealCount) bữa")
        }
        if difference > 0 {
            return String(localized: "Vượt \(VNNumber.int(difference)) kcal · \(mealCount) bữa")
        }
        return String(localized: "Còn \(VNNumber.int(-difference)) kcal · \(mealCount) bữa")
    }

    // MARK: Macros

    /// §6's three cells. Bilingual labels per §4, and each reads its own percentage
    /// of target aloud (§7) — a 4pt bar says "roughly" and nothing more.
    private func macros(_ goal: NutritionGoal) -> some View {
        HStack(alignment: .top, spacing: 14) {
            DayMacroCell(
                vi: "Đạm",
                en: "Protein",
                grams: day.protein,
                targetGrams: goal.protein,
                tint: DS.blue
            )
            DayMacroCell(
                vi: "Tinh bột",
                en: "Carbs",
                grams: day.carbohydrates,
                targetGrams: goal.carbohydrates,
                tint: DS.blue300
            )
            DayMacroCell(
                vi: "Béo",
                en: "Fat",
                grams: day.fat,
                targetGrams: goal.fat,
                tint: DS.blue200
            )
        }
    }

    // MARK: Meals

    private var mealList: some View {
        VStack(spacing: 0) {
            ForEach(day.meals) { meal in
                Rectangle()
                    .fill(DS.borderSubtle)
                    .frame(height: 1)
                mealRow(meal)
            }
        }
    }

    private func mealRow(_ meal: Meal) -> some View {
        Button {
            route = meal.type
        } label: {
            HStack(alignment: .top, spacing: 11) {
                Text(VietnameseDate.time(for: meal.date))
                    .font(.custom(DSFontName.semibold, size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(DS.textMuted)
                    // Wide enough for "06:50" and no wider, so the names below each
                    // other line up.
                    .frame(width: 40, alignment: .leading)

                MealThumbnail(photoID: meal.photos.first?.id, side: 34, radius: 9) {
                    Image(systemName: meal.type.chipSymbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.blueOnSurface)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(meal.type.vi) · \(HistoryDayCard.chipName(for: meal))")
                        .font(.custom(DSFontName.semibold, size: 13.5))
                        .foregroundStyle(DS.textStrong)
                        .lineLimit(2)
                    Text(portionText(meal))
                        .font(.custom(DSFontName.regular, size: 11.5))
                        .foregroundStyle(DS.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.s2)

                Text(VNNumber.int(meal.calories))
                    .font(.custom(DSFontName.bold, size: 13))
                    .monospacedDigit()
                    .foregroundStyle(DS.textBody)
            }
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            // Without this the row only hit-tests where text is drawn, so the gap
            // before the kcal figure is dead space.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(for: meal))
        .accessibilityHint("Chạm hai lần để xem chi tiết bữa này.")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("history.meal.\(meal.type.rawValue)")
    }

    /// "3 món" for a meal of several dishes, the weight for a meal of one — the
    /// figure that is actually informative in each case.
    private func portionText(_ meal: Meal) -> String {
        guard meal.items.count == 1, let only = meal.items.first else {
            return String(localized: "\(meal.items.count) món")
        }
        return "\(VNNumber.int(only.weightGrams)) g"
    }

    /// §7: "06:50, Bữa sáng, Phở bò, 480 ki-lô ca-lo. Có ảnh."
    private func label(for meal: Meal) -> String {
        var label = String(
            localized:
                "\(VietnameseDate.time(for: meal.date)), \(meal.type.vi), \(HistoryDayCard.chipName(for: meal)), \(VNNumber.int(meal.calories)) ki-lô ca-lo."
        )
        if !meal.photos.isEmpty {
            label += String(localized: " Có ảnh.")
        }
        return label
    }
}

/// One of the day panel's three macro cells (§6): label, grams, and a 4pt bar
/// against the day's target.
struct DayMacroCell: View {
    let vi: String
    let en: String
    let grams: Double
    /// 0 when the profile has no target for it, which hides the bar rather than
    /// drawing an empty one.
    let targetGrams: Double
    let tint: Color

    private var fraction: Double {
        guard targetGrams > 0 else { return 0 }
        return min(grams / targetGrams, 1)
    }

    private var percent: Int {
        guard targetGrams > 0 else { return 0 }
        return Int((grams / targetGrams * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(vi) / \(en)")
                .font(.custom(DSFontName.regular, size: 11))
                .foregroundStyle(DS.textMuted)
                .lineLimit(2)
            Text("\(VNNumber.int(grams)) g")
                .font(.custom(DSFontName.bold, size: 14))
                .monospacedDigit()
                .foregroundStyle(DS.textStrong)
                .padding(.top, 1)
            if targetGrams > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DS.trackBg)
                        Capsule()
                            .fill(tint)
                            .frame(width: geometry.size.width * fraction)
                    }
                }
                .frame(height: 4)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isStaticText)
    }

    /// §7: "Đạm 96 gam, 78 phần trăm mục tiêu." The percentage is not clamped the
    /// way the bar is — 130% of a protein target is worth hearing.
    private var accessibilityLabel: String {
        guard targetGrams > 0 else {
            return String(localized: "\(vi) \(VNNumber.int(grams)) gam")
        }
        return String(
            localized: "\(vi) \(VNNumber.int(grams)) gam, \(percent) phần trăm mục tiêu."
        )
    }
}

#if DEBUG
    #Preview("Day panel") {
        HistoryDayPanelSheet(
            day: HistoryPreviewData.dayWithOnePhoto,
            goal: HistoryPreviewData.goal,
            isToday: false,
            onChanged: {},
            onDeleted: {}
        )
        .environment(DependencyContainer(inMemory: true))
    }

    #Preview("Day panel · today, over target") {
        HistoryDayPanelSheet(
            day: HistoryPreviewData.dayOverBudget,
            goal: HistoryPreviewData.goal,
            isToday: true,
            onChanged: {},
            onDeleted: {}
        )
        .environment(DependencyContainer(inMemory: true))
    }

    #Preview("Day panel · accessibility3") {
        HistoryDayPanelSheet(
            day: HistoryPreviewData.dayWithSeveralPhotos,
            goal: HistoryPreviewData.goal,
            isToday: false,
            onChanged: {},
            onDeleted: {}
        )
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(DependencyContainer(inMemory: true))
    }
#endif
