import Domain
import SwiftUI

/// Onboarding — handoff §6.2. One shell, four steps, a sticky bottom CTA.
struct OnboardingView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var model: OnboardingModel?

    let onComplete: () -> Void

    var body: some View {
        Group {
            if let model {
                OnboardingShell(model: model, onComplete: onComplete)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if model == nil { model = container.makeOnboardingModel() }
        }
    }
}

private struct OnboardingShell: View {
    @Bindable var model: OnboardingModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            ScrollView {
                VStack(alignment: .leading, spacing: DS.s5) {
                    stepHeader
                    stepBody
                }
                .padding(.horizontal, 20)
                .padding(.top, DS.s4)
                .padding(.bottom, DS.s6)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .background(DS.surfacePage)
        .alert(
            "Có lỗi xảy ra",
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

    // MARK: Shell chrome

    private var progressHeader: some View {
        HStack(spacing: DS.s3) {
            Button {
                model.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.step.previous == nil ? DS.neutral300 : DS.textBody)
                    .frame(width: 32, height: 32)
                    .background(DS.surfaceSunken, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(model.step.previous == nil)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Quay lại")
            .accessibilityIdentifier("onboarding.back")

            HStack(spacing: DS.s1) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule()
                        .fill(step.rawValue <= model.step.rawValue ? DS.blue : DS.neutral200)
                        .frame(height: 4)
                }
            }

            Text(model.step.counter)
                .font(.custom(DSFontName.semibold, size: 12.5))
                .foregroundStyle(DS.textSubtle)
                .accessibilityIdentifier("onboarding.counter")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, DS.s2)
        .background(DS.surfacePage)
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            Text(model.step.eyebrow)
                .hfStyle(HFType.eyebrow)
                .foregroundStyle(DS.blue)
            Text(model.step.title)
                .font(.custom(DSFontName.extrabold, size: 27))
                .tracking(-0.54)
                .foregroundStyle(DS.textStrong)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.step.subtitle)
                .hfStyle(HFType.body)
                .foregroundStyle(DS.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.stepTitle.\(model.step.rawValue)")
    }

    @ViewBuilder
    private var stepBody: some View {
        switch model.step {
        case .body: BodyStep(model: model)
        case .activity: ActivityStep(model: model)
        case .goal: GoalStep(model: model)
        case .result: ResultStep(model: model)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: DS.s2) {
            Button(model.step.cta) {
                Task { await primaryAction() }
            }
            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
            .disabled(!model.canAdvance || model.isSaving || model.isConnectingHealth)
            .accessibilityIdentifier("onboarding.cta")

            if model.step == .result {
                Button("Để sau") {
                    Task { await finish() }
                }
                .buttonStyle(.ds(.ghost, size: .medium))
                .accessibilityIdentifier("onboarding.skipHealth")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, DS.s3)
        .padding(.bottom, DS.s2)
        .background(DS.surfaceCard)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.borderSubtle).frame(height: 1)
        }
    }

    private func primaryAction() async {
        guard model.step == .result else {
            model.advance()
            return
        }
        await model.connectAppleHealth()
        await finish()
    }

    /// The profile is saved once, at the end — nothing is persisted while the
    /// user is still moving between steps.
    private func finish() async {
        if await model.save() { onComplete() }
    }
}

// MARK: - Step 1

private struct BodyStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            HFCard(padding: 0) {
                VStack(spacing: 0) {
                    row {
                        LabelPair(vi: "Tuổi", en: "Age")
                        Spacer(minLength: DS.s2)
                        HFStepper(
                            value: model.age,
                            range: OnboardingModel.ageRange,
                            identifier: "field.age"
                        ) { model.age = $0 }
                    }
                    separator
                    row {
                        LabelPair(vi: "Chiều cao", en: "Height")
                        Spacer(minLength: DS.s2)
                        HFNumericField(
                            value: $model.heightCm, suffix: "cm", identifier: "field.height"
                        )
                    }
                    if let error = model.heightError { messageRow(error) }
                    separator
                    row {
                        LabelPair(vi: "Cân nặng", en: "Weight")
                        Spacer(minLength: DS.s2)
                        HFNumericField(
                            value: $model.weightKg, suffix: "kg", identifier: "field.weight"
                        )
                    }
                    if let error = model.weightError { messageRow(error) }
                }
            }

            VStack(alignment: .leading, spacing: DS.s2) {
                LabelPair(vi: "Giới tính sinh học", en: "Dùng cho công thức Mifflin-St Jeor")
                HFSegments(
                    options: [
                        (BiologicalSex?.some(.male), BiologicalSex.male.vi, "sex.male"),
                        (BiologicalSex?.some(.female), BiologicalSex.female.vi, "sex.female"),
                        (BiologicalSex?.none, BiologicalSex.preferNotToSay.vi, "sex.unspecified")
                    ],
                    selection: $model.biologicalSex
                )
            }

            if model.usesEstimatedSexConstant {
                GrayNote(
                    text: "Không có giới tính sinh học, mục tiêu sẽ dùng giá trị trung bình nên kém chính xác hơn."
                )
            }
        }
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: DS.s3) { content() }
            .padding(.horizontal, DS.s4)
            .frame(minHeight: 58)
    }

    private func messageRow(_ text: String) -> some View {
        DSFieldMessage(text: text, isError: true)
            .padding(.horizontal, DS.s4)
            .padding(.bottom, DS.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var separator: some View {
        Rectangle().fill(DS.borderSubtle).frame(height: 1).padding(.leading, DS.s4)
    }
}

// MARK: - Step 2

private struct ActivityStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: 9) {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                HFRadioCard(
                    vi: level.vi,
                    en: level.en,
                    meta: level.multiplierText,
                    isSelected: model.activityLevel == level,
                    identifier: "activity.\(level.rawValue)"
                ) {
                    model.activityLevel = level
                }
            }
        }
    }
}

// MARK: - Step 3

private struct GoalStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            HStack(spacing: DS.s2) {
                ForEach(WeightGoal.allCases, id: \.self) { goal in
                    goalTile(goal)
                }
            }

            if model.goal != .maintain {
                HFCard(padding: 0) {
                    HStack(spacing: DS.s3) {
                        LabelPair(vi: "Cân nặng mục tiêu", en: "Target weight")
                        Spacer(minLength: DS.s2)
                        HFNumericField(
                            value: Binding(
                                get: { model.targetWeightKg ?? model.weightKg },
                                set: { model.targetWeightKg = $0 }
                            ),
                            suffix: "kg",
                            identifier: "field.targetWeight"
                        )
                    }
                    .padding(.horizontal, DS.s4)
                    .frame(minHeight: 58)
                }

                if let hint = model.targetWeightHint {
                    DSFieldMessage(text: hint)
                }
            }

            GrayNote(
                text: "Mức thiếu hụt không bao giờ đưa bạn xuống dưới chuyển hóa cơ bản của chính bạn."
            )
        }
    }

    private func goalTile(_ goal: WeightGoal) -> some View {
        let isSelected = model.goal == goal
        return Button {
            model.goal = goal
        } label: {
            VStack(spacing: DS.s1) {
                Text(goal.vi)
                    .font(.custom(DSFontName.bold, size: 15))
                    .foregroundStyle(isSelected ? DS.blue700 : DS.textStrong)
                Text(goal.deltaText)
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.s4)
            .background(isSelected ? DS.blue50 : DS.surfaceCard)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? DS.blue : DS.borderSubtle,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal.\(goal.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step 4

private struct ResultStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            HFCard(padding: DS.s5, radius: 18, accent: DS.blue) {
                VStack(alignment: .leading, spacing: DS.s3) {
                    Text("CALO MỖI NGÀY")
                        .hfStyle(HFType.eyebrow)
                        .foregroundStyle(DS.textSubtle)

                    HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
                        Text(VNNumber.int(model.nutritionGoal.calories))
                            .font(.custom(DSFontName.extrabold, size: 46))
                            .tracking(-1.38)
                            .foregroundStyle(DS.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("kcal")
                            .font(.custom(DSFontName.semibold, size: 16))
                            .foregroundStyle(DS.textMuted)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(VNNumber.int(model.nutritionGoal.calories)) kcal mỗi ngày")
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("result.calories")

                    Text(model.formulaLine)
                        .font(.custom(DSFontName.regular, size: 12.5))
                        .foregroundStyle(DS.textMuted)
                        .accessibilityIdentifier("result.formula")

                    HStack(spacing: DS.s2) {
                        MacroChip(
                            vi: "Đạm", grams: model.nutritionGoal.protein,
                            background: DS.blue50, foreground: DS.blue700
                        )
                        MacroChip(
                            vi: "Tinh bột", grams: model.nutritionGoal.carbohydrates,
                            background: DS.orange100, foreground: DS.orange700
                        )
                        MacroChip(
                            vi: "Chất béo", grams: model.nutritionGoal.fat,
                            background: DS.green100, foreground: DS.green700
                        )
                    }
                }
            }

            HFCard {
                VStack(alignment: .leading, spacing: DS.s3) {
                    HStack(spacing: DS.s2) {
                        Text("BMI \(VNNumber.oneDecimal(model.bmi.value))")
                            .hfStyle(HFType.rowLabel)
                            .foregroundStyle(DS.textStrong)
                        Text("\(model.bmi.category.vi) · \(model.bmi.category.en)")
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(DS.textSubtle)
                        Spacer(minLength: DS.s2)
                        Text(model.bmi.category.en)
                            .hfStyle(HFType.subLabelSemibold)
                            .foregroundStyle(DS.blue700)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DS.blue50, in: Capsule())
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "BMI \(VNNumber.oneDecimal(model.bmi.value)), \(model.bmi.category.vi)"
                    )

                    BMIScaleBar(bmi: model.bmi.value)

                    Text("BMI chỉ là bối cảnh sức khỏe — mục tiêu calo được tính từ tuổi, chiều cao, cân nặng, vận động và mục tiêu của bạn.")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let message = model.healthMessage {
                DSFieldMessage(text: message, isError: true)
            }
        }
    }
}
