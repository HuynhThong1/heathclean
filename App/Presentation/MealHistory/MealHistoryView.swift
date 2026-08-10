import Domain
import SwiftUI

/// Meal history — handoff §6.11.
struct MealHistoryView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var model: MealHistoryModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.s5) {
                header

                if let model {
                    if let message = model.errorMessage {
                        GrayNote(text: message)
                    } else if model.days.isEmpty {
                        // Empty state reuses the neutral note style, no
                        // illustration (§6.11).
                        GrayNote(text: "Chưa có bữa ăn nào được ghi. Những bữa bạn ghi sẽ xuất hiện ở đây.")
                    } else {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(model.days) { day in
                                daySection(day, goal: model.dailyGoalCalories)
                            }
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, DS.s2)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(DS.surfacePage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if model == nil { model = container.makeMealHistoryModel() }
            await model?.load()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DS.s3) {
            HFBackChip { dismiss() }
                .accessibilityIdentifier("history.back")

            VStack(alignment: .leading, spacing: DS.s1) {
                Text("LỊCH SỬ · HISTORY")
                    .hfStyle(HFType.eyebrow)
                    .foregroundStyle(DS.textSubtle)
                Text("Bữa ăn đã ghi")
                    .font(.custom(DSFontName.extrabold, size: 29))
                    .tracking(-0.725)
                    .foregroundStyle(DS.textStrong)
            }
            Spacer(minLength: 0)
        }
    }

    private func daySection(_ day: MealHistoryModel.Day, goal: Double) -> some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
                Text(VietnameseDate.dayText(for: day.date))
                    .font(.custom(DSFontName.bold, size: 14))
                    .foregroundStyle(DS.textStrong)
                if goal > 0 {
                    Text("\(VNNumber.int(day.calories)) / \(VNNumber.int(goal))")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                }
                Spacer(minLength: DS.s2)
                Text("\(VNNumber.int(day.calories)) kcal")
                    .font(.custom(DSFontName.bold, size: 13))
                    .foregroundStyle(DS.textStrong)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(VietnameseDate.dayText(for: day.date)), \(VNNumber.int(day.calories)) kcal"
            )
            .accessibilityAddTraits(.isStaticText)

            dayProgress(consumed: day.calories, goal: goal)

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
    }

    /// Blue under goal, neutral grey over — the same non-alarming treatment the
    /// dashboard ring uses (§4).
    private func dayProgress(consumed: Double, goal: Double) -> some View {
        let fraction = goal > 0 ? min(consumed / goal, 1) : 0
        let isOver = goal > 0 && consumed > goal
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(DS.neutral150)
                Capsule()
                    .fill(isOver ? DS.neutral400 : DS.blue)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private func mealRow(_ meal: Meal) -> some View {
        HStack(spacing: DS.s3) {
            Image(systemName: meal.type.chipSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.textBody)
                .frame(width: 28, height: 28)
                .background(meal.type.chipColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(meal.type.vi), \(VNNumber.int(meal.calories)) kcal")
    }
}
