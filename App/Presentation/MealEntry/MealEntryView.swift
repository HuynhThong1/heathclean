import Domain
import SwiftUI

struct MealEntryView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var model: MealEntryModel?

    let type: MealType
    let onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    form(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(type.title)
            .dsScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(DSType.bodyMedium)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await model?.save() == true {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .font(DSType.bodySemibold)
                    .disabled(model?.canSave != true)
                }
            }
        }
        .onAppear {
            if model == nil {
                model = container.makeMealEntryModel(type: type, date: Date())
            }
        }
    }

    private func form(model: MealEntryModel) -> some View {
        @Bindable var model = model

        return Form {
            ForEach(Array($model.drafts.enumerated()), id: \.element.id) { index, $draft in
                Section {
                    TextField("Food", text: $draft.name)
                        .font(DSType.bodyMedium)
                        .foregroundStyle(DSColor.textStrong)
                        .accessibilityIdentifier("field.food")
                    NumberField(title: "Weight", unit: "g", value: $draft.weightGrams)
                    NumberField(title: "Calories", unit: "kcal", value: $draft.calories)
                    NumberField(title: "Protein", unit: "g", value: $draft.protein)
                    NumberField(title: "Carbs", unit: "g", value: $draft.carbohydrates)
                    NumberField(title: "Fat", unit: "g", value: $draft.fat)
                } header: {
                    DSSectionHeader(title: model.drafts.count > 1 ? "Food \(index + 1)" : "Food")
                }
                .dsRow()
            }
            .onDelete { model.removeDrafts(at: $0) }

            Section {
                Button {
                    model.addDraft()
                } label: {
                    Label("Add another food", systemImage: "plus")
                        .font(DSType.bodyMedium)
                        .foregroundStyle(DSColor.brandOnSurface)
                }
            }
            .dsRow()

            Section {
                totalsCard(model: model)
                    .listRowInsets(EdgeInsets(top: Space.s2, leading: Space.s4,
                                              bottom: Space.s2, trailing: Space.s4))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func totalsCard(model: MealEntryModel) -> some View {
        DSCard(padding: .medium, accent: .green) {
            VStack(alignment: .leading, spacing: Space.s3) {
                DSStatBlock(
                    value: Int(model.totalCalories.rounded()).formatted(),
                    label: "kcal in this meal",
                    tone: .green
                )
                Divider().overlay(DSColor.borderSubtle)
                TotalLine(name: "Protein", grams: model.totalProtein)
                TotalLine(name: "Carbs", grams: model.totalCarbohydrates)
                TotalLine(name: "Fat", grams: model.totalFat)
            }
        }
    }
}

private struct TotalLine: View {
    let name: String
    let grams: Double

    var body: some View {
        DSValueRow(name: name, value: "\(Int(grams.rounded())) g")
    }
}

private struct NumberField: View {
    let title: String
    let unit: String
    @Binding var value: Double

    var body: some View {
        LabeledContent {
            HStack {
                TextField(title, value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(DSType.bodyMedium)
                    .foregroundStyle(DSColor.textStrong)
                    .accessibilityIdentifier("field.\(title.lowercased())")
                Text(unit)
                    .font(DSType.bodySmall)
                    .foregroundStyle(DSColor.textSubtle)
            }
        } label: {
            Text(title)
                .font(DSType.body)
                .foregroundStyle(DSColor.textBody)
        }
    }
}
