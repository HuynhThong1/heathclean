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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            ForEach($model.drafts) { $draft in
                Section {
                    TextField("Food", text: $draft.name)
                        .accessibilityIdentifier("field.food")
                    NumberField(title: "Weight", unit: "g", value: $draft.weightGrams)
                    NumberField(title: "Calories", unit: "kcal", value: $draft.calories)
                    NumberField(title: "Protein", unit: "g", value: $draft.protein)
                    NumberField(title: "Carbs", unit: "g", value: $draft.carbohydrates)
                    NumberField(title: "Fat", unit: "g", value: $draft.fat)
                }
            }
            .onDelete { model.removeDrafts(at: $0) }

            Section {
                Button("Add another food", systemImage: "plus") {
                    model.addDraft()
                }
            }

            Section("Meal total") {
                LabeledContent("Calories") {
                    Text("\(Int(model.totalCalories.rounded())) kcal")
                }
                LabeledContent("Protein") { Text("\(Int(model.totalProtein.rounded())) g") }
                LabeledContent("Carbs") { Text("\(Int(model.totalCarbohydrates.rounded())) g") }
                LabeledContent("Fat") { Text("\(Int(model.totalFat.rounded())) g") }
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
}

private struct NumberField: View {
    let title: String
    let unit: String
    @Binding var value: Double

    var body: some View {
        LabeledContent(title) {
            HStack {
                TextField(title, value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("field.\(title.lowercased())")
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
