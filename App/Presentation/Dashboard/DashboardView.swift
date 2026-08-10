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
            .dsScreen()
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
                budgetCard(model: model, summary: summary)
                    .listRowInsets(EdgeInsets(top: Space.s2, leading: Space.s4,
                                              bottom: Space.s2, trailing: Space.s4))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                MacroRow(name: "Protein", consumed: summary.consumedProtein, target: summary.goal.protein)
                MacroRow(name: "Carbs", consumed: summary.consumedCarbohydrates, target: summary.goal.carbohydrates)
                MacroRow(name: "Fat", consumed: summary.consumedFat, target: summary.goal.fat)
            } header: {
                DSSectionHeader(title: "Macros")
            }
            .dsRow()

            Section {
                ForEach(MealType.allCases, id: \.self) { type in
                    let calories = summary.meals(of: type).reduce(0) { $0 + $1.calories }
                    Button {
                        entryType = type
                    } label: {
                        MealRow(title: type.title, calories: calories)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mealRow.\(type.rawValue)")
                }
            } header: {
                DSSectionHeader(title: "Meals")
            }
            .dsRow()

            if let health = model.health, !health.isEmpty {
                Section {
                    if let steps = health.steps {
                        DSValueRow(name: "Steps", value: steps.formatted())
                    }
                    if let active = health.activeEnergyKcal {
                        DSValueRow(name: "Active", value: "\(Int(active.rounded())) kcal")
                    }
                    if let total = health.totalEnergyBurnedKcal, health.basalEnergyKcal != nil {
                        DSValueRow(name: "Total burned", value: "\(Int(total.rounded())) kcal")
                    }
                    if let sleep = health.sleepDuration {
                        DSValueRow(name: "Sleep", value: Self.sleepText(sleep))
                    }
                    if let weight = health.weightKg {
                        DSValueRow(
                            name: "Weight",
                            value: weight.formatted(.number.precision(.fractionLength(1))) + " kg"
                        )
                    }
                } header: {
                    DSSectionHeader(title: "Activity")
                }
                .dsRow()
            }

            if let bmi = model.bmi {
                Section {
                    BMILine(bmi: bmi)
                } header: {
                    DSSectionHeader(title: "Health context")
                }
                .dsRow()
            }
        }
    }

    private func budgetCard(model: DashboardModel, summary: DailyNutritionSummary) -> some View {
        DSCard(padding: .medium, accent: model.status.accent) {
            VStack(alignment: .leading, spacing: Space.s4) {
                DSStatBlock(
                    value: Int(summary.consumedCalories.rounded()).formatted(),
                    label: "kcal eaten",
                    sublabel: remainingLabel(for: summary),
                    tone: model.status.statTone
                )

                ProgressView(value: min(summary.budget.fractionUsed, 1))
                    .tint(model.status.tint)

                HStack {
                    Text("Target")
                        .font(DSType.bodySmall)
                        .foregroundStyle(DSColor.textMuted)
                    Spacer()
                    Text("\(Int(summary.goal.calories.rounded()).formatted()) kcal")
                        .font(DSType.bodySmallSemibold)
                        .foregroundStyle(DSColor.textBody)
                }

                if let message = model.statusMessage {
                    Text(message)
                        .font(DSType.bodySmall)
                        .foregroundStyle(DSColor.textBody)
                        .padding(.top, Space.s1)
                }
            }
        }
    }

    /// "7h 32m", matching plan.md §6.
    private static func sleepText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func remainingLabel(for summary: DailyNutritionSummary) -> String {
        let remaining = summary.budget.remaining
        let magnitude = Int(abs(remaining).rounded()).formatted()
        return remaining >= 0 ? "\(magnitude) kcal remaining" : "\(magnitude) kcal over"
    }
}

private struct MacroRow: View {
    let name: String
    let consumed: Double
    let target: Double

    var body: some View {
        DSValueRow(
            name: name,
            value: "\(Int(consumed.rounded())) / \(Int(target.rounded())) g"
        )
    }
}

private struct MealRow: View {
    let title: String
    let calories: Double

    var body: some View {
        DSValueRow(
            name: title,
            value: "\(Int(calories.rounded())) kcal",
            valueColor: calories > 0 ? DSColor.brandOnSurface : DSColor.textSubtle
        )
        // Without this the gap between label and value is dead space and the
        // row only responds on the text itself.
        .contentShape(Rectangle())
    }
}
