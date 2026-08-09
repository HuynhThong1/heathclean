import Domain
import SwiftUI

struct OnboardingView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var model: OnboardingModel?

    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            if let model {
                OnboardingForm(model: model, onComplete: onComplete)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if model == nil { model = container.makeOnboardingModel() }
        }
    }
}

private struct OnboardingForm: View {
    @Bindable var model: OnboardingModel
    let onComplete: () -> Void

    var body: some View {
        Form {
            Section("About you") {
                Stepper("Age: \(model.age)", value: $model.age, in: 13...120)

                MeasurementField(title: "Height", unit: "cm", value: $model.heightCm)
                MeasurementField(title: "Weight", unit: "kg", value: $model.weightKg)

                Picker("Biological sex", selection: $model.biologicalSex) {
                    Text("Prefer not to say").tag(BiologicalSex?.none)
                    Text("Female").tag(BiologicalSex?.some(.female))
                    Text("Male").tag(BiologicalSex?.some(.male))
                }
            }

            Section("Activity") {
                Picker("Typical week", selection: $model.activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Goal") {
                Picker("I want to", selection: $model.goal) {
                    ForEach(WeightGoal.allCases, id: \.self) { goal in
                        Text(goal.title).tag(goal)
                    }
                }
                .pickerStyle(.segmented)

                if model.goal != .maintain {
                    MeasurementField(
                        title: "Target weight",
                        unit: "kg",
                        value: Binding(
                            get: { model.targetWeightKg ?? model.weightKg },
                            set: { model.targetWeightKg = $0 }
                        )
                    )
                }
            }

            Section("Your daily targets") {
                LabeledContent("BMI") {
                    Text("\(model.bmi.value, format: .number.precision(.fractionLength(1)))")
                        + Text(" · \(model.bmi.category.title)")
                }
                LabeledContent("Calories") {
                    Text("\(Int(model.nutritionGoal.calories.rounded())) kcal")
                }
                LabeledContent("Protein") {
                    Text("\(Int(model.nutritionGoal.protein.rounded())) g")
                }
                LabeledContent("Carbs") {
                    Text("\(Int(model.nutritionGoal.carbohydrates.rounded())) g")
                }
                LabeledContent("Fat") {
                    Text("\(Int(model.nutritionGoal.fat.rounded())) g")
                }

                if model.usesEstimatedSexConstant {
                    Text(
                        """
                        Without a biological sex these targets use an average \
                        estimate, so they are less precise.
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("BMI is health context only — your calorie target comes from your age, height, weight, activity and goal.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Set up")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Continue") {
                    Task {
                        if await model.save() { onComplete() }
                    }
                }
                .disabled(!model.isValid || model.isSaving)
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

private struct MeasurementField: View {
    let title: String
    let unit: String
    @Binding var value: Double

    var body: some View {
        LabeledContent(title) {
            HStack {
                TextField(title, value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
