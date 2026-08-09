import Domain
import SwiftUI

struct DashboardView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var model: DashboardModel?
    @State private var entryType: MealType?

    var body: some View {
        NavigationStack {
            Group {
                if let model, let summary = model.summary {
                    content(model: model, summary: summary)
                } else if let message = model?.errorMessage {
                    ContentUnavailableView(
                        "Couldn't load today",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MealHistoryView()
                    } label: {
                        Label("History", systemImage: "clock")
                    }
                }
            }
        }
        .task {
            if model == nil { model = container.makeDashboardModel() }
            await model?.load()
        }
        .sheet(item: $entryType) { type in
            MealEntryView(type: type) {
                Task { await model?.load() }
            }
        }
    }

    private func content(model: DashboardModel, summary: DailyNutritionSummary) -> some View {
        List {
            Section {
                CalorieRing(summary: summary, status: model.status)
                if let message = model.statusMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(model.status.tint)
                }
            }

            Section("Macros") {
                MacroRow(name: "Protein", consumed: summary.consumedProtein, target: summary.goal.protein)
                MacroRow(name: "Carbs", consumed: summary.consumedCarbohydrates, target: summary.goal.carbohydrates)
                MacroRow(name: "Fat", consumed: summary.consumedFat, target: summary.goal.fat)
            }

            Section("Meals") {
                ForEach(MealType.allCases, id: \.self) { type in
                    let calories = summary.meals(of: type).reduce(0) { $0 + $1.calories }
                    Button {
                        entryType = type
                    } label: {
                        LabeledContent(type.title) {
                            Text("\(Int(calories.rounded())) kcal")
                                .foregroundStyle(.secondary)
                        }
                        // Without this the gap between label and value is dead
                        // space and the row only responds on the text itself.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mealRow.\(type.rawValue)")
                }
            }

            if let bmi = model.bmi {
                Section("Health context") {
                    LabeledContent("BMI") {
                        Text("\(bmi.value, format: .number.precision(.fractionLength(1))) · \(bmi.category.title)")
                    }
                }
            }
        }
    }
}

private struct CalorieRing: View {
    let summary: DailyNutritionSummary
    let status: CalorieBudgetStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(Int(summary.consumedCalories.rounded())) kcal eaten")
                .font(.title2.weight(.semibold))

            Text(remainingLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: min(summary.budget.fractionUsed, 1))
                .tint(status.tint)

            LabeledContent("Target") {
                Text("\(Int(summary.goal.calories.rounded())) kcal")
            }
            .font(.footnote)
        }
        .padding(.vertical, 4)
    }

    private var remainingLabel: String {
        let remaining = summary.budget.remaining
        // `.formatted()` so this groups digits the same way the interpolated
        // totals elsewhere on this screen do.
        let magnitude = Int(abs(remaining).rounded()).formatted()
        return remaining >= 0 ? "\(magnitude) kcal remaining" : "\(magnitude) kcal over"
    }
}

private struct MacroRow: View {
    let name: String
    let consumed: Double
    let target: Double

    var body: some View {
        LabeledContent(name) {
            Text("\(Int(consumed.rounded())) / \(Int(target.rounded())) g")
                .foregroundStyle(.secondary)
        }
    }
}
