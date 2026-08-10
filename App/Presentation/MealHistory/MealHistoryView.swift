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
        .dsScreen()
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
                        DSValueRow(
                            name: meal.type.title,
                            value: "\(Int(meal.calories.rounded())) kcal",
                            valueColor: DSColor.brandOnSurface
                        )
                    }
                } header: {
                    HStack {
                        Text(day.date, format: .dateTime.weekday(.abbreviated).day().month())
                            .font(DSType.overline)
                            .kerning(1.44)
                            .foregroundStyle(DSColor.textMuted)
                        Spacer()
                        DSBadge(
                            text: "\(Int(day.calories.rounded()).formatted()) kcal",
                            tone: .blue
                        )
                    }
                }
                .dsRow()
            }
        }
    }
}
