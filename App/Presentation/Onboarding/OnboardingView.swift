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
            Section {
                Stepper("Age: \(model.age)", value: $model.age, in: 13...120)
                    .font(DSType.body)
                    .foregroundStyle(DSColor.textBody)

                MeasurementField(
                    title: "Height", unit: "cm", value: $model.heightCm,
                    error: model.heightError
                )
                MeasurementField(
                    title: "Weight", unit: "kg", value: $model.weightKg,
                    error: model.weightError
                )

                Picker("Biological sex", selection: $model.biologicalSex) {
                    Text("Prefer not to say").tag(BiologicalSex?.none)
                    Text("Female").tag(BiologicalSex?.some(.female))
                    Text("Male").tag(BiologicalSex?.some(.male))
                }
                .font(DSType.body)
            } header: {
                DSSectionHeader(title: "About you")
            }
            .dsRow()

            Section {
                Picker("Typical week", selection: $model.activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .font(DSType.body)
            } header: {
                DSSectionHeader(title: "Activity")
            }
            .dsRow()

            Section {
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
                        ),
                        hint: model.targetWeightHint
                    )
                }
            } header: {
                DSSectionHeader(title: "Goal")
            }
            .dsRow()

            Section {
                targetsCard
                    .listRowInsets(EdgeInsets(top: Space.s2, leading: Space.s4,
                                              bottom: Space.s2, trailing: Space.s4))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } header: {
                DSSectionHeader(title: "Your daily targets")
            }

            Section {
                Text("BMI is health context only — your calorie target comes from your age, height, weight, activity and goal.")
                    .font(DSType.caption)
                    .foregroundStyle(DSColor.textMuted)
            }
            .dsRow()
        }
        .navigationTitle("Set up")
        .dsScreen()
        .safeAreaInset(edge: .bottom) {
            Button("Continue") {
                Task {
                    if await model.save() { onComplete() }
                }
            }
            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
            .disabled(!model.isValid || model.isSaving)
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s3)
            .background(.bar)
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

    private var targetsCard: some View {
        DSCard(padding: .medium, accent: model.isValid ? .blue : nil) {
            if model.isValid {
                validTargets
            } else {
                // Height and weight feed every number here, so out-of-range
                // input produces confident nonsense (500 kg reads as 9,043 kcal
                // and BMI 173). Withhold the figures rather than show them.
                VStack(alignment: .leading, spacing: Space.s2) {
                    Text("Targets unavailable")
                        .font(DSType.h4)
                        .foregroundStyle(DSColor.textStrong)
                    Text("Enter a height and weight in range and your daily targets will appear here.")
                        .font(DSType.bodySmall)
                        .foregroundStyle(DSColor.textMuted)
                }
            }
        }
    }

    private var validTargets: some View {
        Group {
            VStack(alignment: .leading, spacing: Space.s3) {
                DSStatBlock(
                    value: Int(model.nutritionGoal.calories.rounded()).formatted(),
                    label: "kcal per day",
                    tone: .blue
                )

                Divider().overlay(DSColor.borderSubtle)

                BMILine(bmi: model.bmi)
                MacroLine(name: "Protein", grams: model.nutritionGoal.protein)
                MacroLine(name: "Carbs", grams: model.nutritionGoal.carbohydrates)
                MacroLine(name: "Fat", grams: model.nutritionGoal.fat)

                if model.usesEstimatedSexConstant {
                    Text(
                        """
                        Without a biological sex these targets use an average \
                        estimate, so they are less precise.
                        """
                    )
                    .font(DSType.caption)
                    .foregroundStyle(DSColor.textMuted)
                }
            }
        }
    }
}

private struct MacroLine: View {
    let name: String
    let grams: Double

    var body: some View {
        DSValueRow(name: name, value: "\(Int(grams.rounded())) g")
    }
}

private struct MeasurementField: View {
    let title: String
    let unit: String
    @Binding var value: Double
    var error: String?
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            field
            if let error {
                DSFieldMessage(text: error, isError: true)
            } else if let hint {
                DSFieldMessage(text: hint)
            }
        }
    }

    private var field: some View {
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
