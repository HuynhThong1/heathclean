import Domain
import SwiftUI

struct MealHistoryView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var model: MealHistoryModel?

    var body: some View {
        Group {
            if let model {
                if let message = model.errorMessage {
                    ContentUnavailableView(
                        "Couldn't load history",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                } else if model.days.isEmpty {
                    ContentUnavailableView(
                        "No meals yet",
                        systemImage: "fork.knife",
                        description: Text("Meals you log will appear here.")
                    )
                } else {
                    list(model: model)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("History")
        .task {
            if model == nil { model = container.makeMealHistoryModel() }
            await model?.load()
        }
    }

    private func list(model: MealHistoryModel) -> some View {
        List {
            ForEach(model.days) { day in
                Section {
                    ForEach(day.meals) { meal in
                        LabeledContent(meal.type.title) {
                            Text("\(Int(meal.calories.rounded())) kcal")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    LabeledContent {
                        Text("\(Int(day.calories.rounded())) kcal")
                    } label: {
                        Text(day.date, format: .dateTime.weekday(.abbreviated).day().month())
                    }
                }
            }
        }
    }
}
