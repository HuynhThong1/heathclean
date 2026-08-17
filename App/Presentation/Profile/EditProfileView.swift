import Domain
import SwiftUI
import UIKit

/// PROFILE_SPEC §5 — "Sửa hồ sơ".
///
/// **Push, not a sheet.** The form is long and carries a pinned Save bar; a
/// sheet would put a drag-to-dismiss gesture on a screen whose whole point is
/// that leaving it without saving is a decision worth confirming (§5, state C).
///
/// It replaces the four onboarding steps this screen used to reuse. Those are
/// right for a first run — one decision per screen, no way back into the app
/// until they are answered — and wrong for an edit, where the user came to
/// change one number and needs to see what it does to the target.
struct EditProfileView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var model: EditProfileModel?
    @State private var sheet: FieldSheet?
    @State private var isConfirmingDiscard = false

    let onSaved: () -> Void

    private enum FieldSheet: String, Identifiable {
        case sex, activity, goal
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            DS.surfacePage.ignoresSafeArea()

            if let model {
                form(model)
                    .disabled(model.didSave)
                if model.didSave {
                    SavedConfirmation(goal: model.nutritionGoal) { dismiss() }
                }
            } else {
                ProgressView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if model == nil { model = container.makeEditProfileModel() }
            await model?.load()
        }
    }

    // MARK: Shell

    private func form(_ model: EditProfileModel) -> some View {
        VStack(spacing: 0) {
            header(model)

            ScrollView {
                VStack(spacing: 0) {
                    NewGoalCard(model: model)
                        .padding(.top, DS.s4)

                    basics(model)
                    bodySection(model)
                    goals(model)
                    HowItIsCalculated(model: model)
                        .padding(.top, 22)
                }
                .padding(.horizontal, DS.s4)
                .padding(.bottom, DS.s5)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            saveBar(model)
        }
        .sheet(item: $sheet) { which in
            sheetContent(which, model: model)
        }
        // §5, state C. Only when something has actually changed, and the default
        // answer is the one that keeps the work.
        //
        // **`.confirmationDialog` is what §5 names, and it does not present from
        // this screen** — tried on the button, on the stack and on the screen,
        // and in all three the state flipped and nothing appeared, while the
        // same three-line change to `.alert` worked first time. `HFDestructiveConfirm`
        // is where this app already went for the same reason a year of design
        // notes gives: a system sheet is system-faced in a screen that is
        // entirely `DS.*`. It is also **what §5's own mock draws** — a card from
        // the bottom, "Bỏ thay đổi" quiet above "Tiếp tục sửa" in blue — which
        // an action sheet could only approximate.
        .sheet(isPresented: $isConfirmingDiscard) {
            HFDestructiveConfirm(
                title: L("Bỏ thay đổi?"),
                message: model.originalGoal.map {
                    L("Mục tiêu calo sẽ giữ nguyên \(AppNumber.int($0.calories)) kcal.")
                } ?? L("Hồ sơ sẽ giữ nguyên như trước."),
                confirmLabel: L("Bỏ thay đổi"),
                cancelLabel: L("Tiếp tục sửa"),
                emphasis: .reversible,
                onConfirm: {
                    isConfirmingDiscard = false
                    dismiss()
                },
                onCancel: { isConfirmingDiscard = false }
            )
        }
    }

    /// §5's nav bar, drawn rather than configured: the app hides the navigation
    /// bar everywhere (`DSAppearance` cannot style a two-action bar to the
    /// handoff's measurements), and every screen that does so owes the user a
    /// visible way back. Here that is "Huỷ", which is also the affordance state
    /// C hangs off.
    private func header(_ model: EditProfileModel) -> some View {
        HStack(spacing: DS.s3) {
            Button { attemptLeave(model) } label: {
                Text("Huỷ")
                    .font(.custom(DSFontName.medium, size: 15, relativeTo: .body))
                    .foregroundStyle(DS.blueOnSurface)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editProfile.cancel")

            Text("Sửa hồ sơ")
                .font(.custom(DSFontName.bold, size: 15.5, relativeTo: .headline))
                .foregroundStyle(DS.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            Button { save(model) } label: {
                Text("Lưu")
                    .font(.custom(DSFontName.bold, size: 15, relativeTo: .body))
                    .foregroundStyle(DS.blueOnSurface)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!model.canSave)
            .opacity(model.canSave ? 1 : 0.4)
            .accessibilityIdentifier("editProfile.save")
        }
        .padding(.horizontal, DS.s4)
        .padding(.top, DS.s2)
        .padding(.bottom, DS.s3)
        // The *ViewBuilder* overload, because the strip draws a hairline under
        // itself — and that overload stops at the safe area, so the stack takes
        // `.ignoresSafeArea(edges: .top)` or content scrolls up through the
        // clock. `HFTabBar` records the same trap at the other end of the screen.
        .background {
            VStack(spacing: 0) {
                DS.surfacePage
                Rectangle().fill(DS.borderSubtle).frame(height: 1)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: Sections

    private func basics(_ model: EditProfileModel) -> some View {
        VStack(spacing: 0) {
            SectionLabel("CƠ BẢN")
            SettingsCard {
                SettingsRow(
                    "Giới tính",
                    caption: "Dùng để ước lượng mức trao đổi chất cơ bản.",
                    value: model.biologicalSex?.label ?? L("Chưa chọn"),
                    prominent: true,
                    showsChevron: true,
                    identifier: "editProfile.sex"
                ) { sheet = .sex }

                SettingsDivider()

                // §5 draws "Ngày sinh". `UserProfile` stores an age and nothing
                // else; a date of birth is a Domain change with a store
                // migration behind it, and the rule here is that the Domain
                // layer is not reshaped to match a screen. Age is what the
                // calorie model reads, so age is what the form edits.
                SettingsRow("Tuổi", hasInteractiveTrailing: true) {
                    IntegerRowField(
                        value: bind(model, \.age),
                        identifier: "field.age",
                        accessibilityLabel: L("Tuổi")
                    )
                }
            }
        }
    }

    private func bodySection(_ model: EditProfileModel) -> some View {
        VStack(spacing: 0) {
            SectionLabel("CƠ THỂ")
            SettingsCard {
                SettingsRow("Chiều cao", hasInteractiveTrailing: true) {
                    DecimalRowField(
                        value: bind(model, \.heightCm),
                        unit: "cm",
                        identifier: "field.height",
                        accessibilityLabel: L("Chiều cao"),
                        fractionDigits: 0
                    )
                }

                SettingsDivider()

                SettingsRow(
                    "Cân nặng hiện tại",
                    caption: "Cập nhật khi bạn muốn — không có nhắc nhở cân hằng ngày.",
                    hasInteractiveTrailing: true
                ) {
                    DecimalRowField(
                        value: bind(model, \.weightKg),
                        unit: "kg",
                        identifier: "field.weight",
                        accessibilityLabel: L("Cân nặng hiện tại")
                    )
                }
            }
        }
    }

    private func goals(_ model: EditProfileModel) -> some View {
        VStack(spacing: 0) {
            SectionLabel("MỤC TIÊU")
            SettingsCard {
                // Not in §5's layout, and needed because the "TỐC ĐỘ" segmented
                // control is not built: that control assumed losing weight, and
                // without either of them there would be no way to change
                // direction from this screen at all. See CLAUDE.md.
                SettingsRow(
                    "Hướng mục tiêu",
                    value: model.goal.label,
                    prominent: true,
                    showsChevron: true,
                    identifier: "editProfile.goal"
                ) { sheet = .goal }

                if model.goal != .maintain {
                    SettingsDivider()

                    SettingsRow("Cân nặng mục tiêu", hasInteractiveTrailing: true) {
                        DecimalRowField(
                            value: bindTargetWeight(model),
                            unit: "kg",
                            identifier: "field.targetWeight",
                            accessibilityLabel: L("Cân nặng mục tiêu")
                        )
                    }

                    if model.isTargetBelowSafeRange {
                        OutsideSafeRangeNote(model: model)
                            .padding(.horizontal, DS.s4)
                            .padding(.bottom, DS.s4)
                    }
                }

                SettingsDivider()

                SettingsRow(
                    "Mức vận động",
                    caption: nil,
                    value: model.activityLevel.shortLabel,
                    prominent: true,
                    showsChevron: true,
                    identifier: "editProfile.activity"
                ) { sheet = .activity }
            }
        }
    }

    @ViewBuilder
    private func sheetContent(_ which: FieldSheet, model: EditProfileModel) -> some View {
        switch which {
        case .sex:
            ChoiceSheet(
                title: "Giới tính",
                options: BiologicalSex.allCases.map {
                    ChoiceOption(
                        value: BiologicalSex?.some($0),
                        title: $0.label,
                        identifier: "choice.sex.\($0.rawValue)"
                    )
                },
                selection: bind(model, \.biologicalSex),
                identifier: "sheet.sex"
            )
        case .activity:
            ChoiceSheet(
                title: "Mức vận động",
                options: ActivityLevel.allCases.map {
                    ChoiceOption(
                        value: $0,
                        title: $0.shortLabel,
                        detail: $0.detail,
                        identifier: "choice.activity.\($0.rawValue)"
                    )
                },
                selection: bind(model, \.activityLevel),
                identifier: "sheet.activity"
            )
        case .goal:
            ChoiceSheet(
                title: "Hướng mục tiêu",
                options: WeightGoal.allCases.map {
                    ChoiceOption(
                        value: $0,
                        title: $0.label,
                        detail: $0.editDetail,
                        identifier: "choice.goal.\($0.rawValue)"
                    )
                },
                selection: bind(model, \.goal),
                identifier: "sheet.goal"
            )
        }
    }

    // MARK: Save bar

    /// §5: height 50, corner 13, pinned. `disabled` plus 0.4 opacity when there
    /// is nothing to save, so the button says which of the two it is.
    private func saveBar(_ model: EditProfileModel) -> some View {
        VStack(spacing: DS.s2) {
            if let message = model.errorMessage {
                Text(verbatim: message)
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { save(model) } label: {
                Text("Lưu thay đổi")
                    .font(.custom(DSFontName.semibold, size: 15.5, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.blue, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!model.canSave)
            .opacity(model.canSave ? 1 : 0.4)
            .accessibilityIdentifier("editProfile.saveBar")
        }
        .padding(.horizontal, DS.s4)
        .padding(.top, DS.s3)
        // The screen does not inset its own content for the home indicator here
        // — the bar is pinned outside the scroll view — so its bottom padding is
        // the only clearance there is. Same rule `HFDestructiveConfirm` records.
        .padding(.bottom, DS.s4)
        .background {
            VStack(spacing: 0) {
                Rectangle().fill(DS.borderSubtle).frame(height: 1)
                DS.surfaceCard
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: Actions

    private func save(_ model: EditProfileModel) {
        Task {
            guard await model.save() else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved()
            // §5, state D: the confirmation says what saving actually did, then
            // gets out of the way. 1.2s is long enough to read one sentence and
            // short enough that nobody waits for it. A tap dismisses sooner, and
            // dismissing twice is harmless — the second call lands on a screen
            // that is already gone.
            try? await Task.sleep(for: .milliseconds(1_200))
            dismiss()
        }
    }

    private func attemptLeave(_ model: EditProfileModel) {
        if model.isDirty {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    // MARK: Bindings

    /// `@Observable` gives no `$` projection, so a field's binding is written
    /// out. One helper rather than seven closures.
    private func bind<Value>(
        _ model: EditProfileModel,
        _ keyPath: ReferenceWritableKeyPath<EditProfileModel, Value>
    ) -> Binding<Value> {
        Binding(get: { model[keyPath: keyPath] }, set: { model[keyPath: keyPath] = $0 })
    }

    /// The target weight is optional in Domain — "no target" and "a target of
    /// zero" are different — but the field on screen is a number. It reads back
    /// as the current weight when unset, which is the only value that is not a
    /// claim.
    private func bindTargetWeight(_ model: EditProfileModel) -> Binding<Double> {
        Binding(
            get: { model.targetWeightKg ?? model.weightKg },
            set: { model.targetWeightKg = $0 }
        )
    }
}

// MARK: - The new goal (§5.1)

/// The figure the whole screen exists to move, and it moves **as the form is
/// edited**, not when it is saved.
///
/// The caption is the other half of that: a number that changed without saying
/// why invites the user to hunt for what they touched.
private struct NewGoalCard: View {
    let model: EditProfileModel

    private var calories: String { AppNumber.int(model.nutritionGoal.calories) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.isDirty ? "MỤC TIÊU MỚI" : "MỤC TIÊU HIỆN TẠI")
                .hfStyle(ProfileType.goalEyebrow)
                .foregroundStyle(Self.onBrand)

            // The 34pt figure scales with Dynamic Type, so at an accessibility
            // size the unit beside it no longer fits on the line. `ViewThatFits`
            // rather than a size test: what matters is whether these two
            // actually fit, which depends on the figure's digits as well as the
            // text size.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
                    figure
                    unit
                }
                VStack(alignment: .leading, spacing: 2) {
                    figure
                    unit
                }
            }
            .padding(.top, 9)

            if let caption {
                Text(verbatim: caption)
                    .font(.custom(DSFontName.regular, size: 12, relativeTo: .footnote))
                    .foregroundStyle(Self.onBrand)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DS.s2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, DS.s4)
        .background(DS.blue, in: RoundedRectangle(cornerRadius: DS.rCard, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: model.nutritionGoal.calories)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("editProfile.newGoal")
        .accessibilityLabel(
            Text(verbatim: L("Mục tiêu mới \(calories) ki-lô ca-lo mỗi ngày"))
        )
        .accessibilityAddTraits(.isStaticText)
        // VoiceOver does not re-read an element that changed while focus is
        // elsewhere — and focus is on the field being edited, which is the whole
        // point. Without this the target moves silently for the users least able
        // to notice.
        .onChange(of: model.nutritionGoal.calories) {
            AccessibilityNotification.Announcement(
                L("Mục tiêu mới \(calories) ki-lô ca-lo mỗi ngày")
            ).post()
        }
    }

    private var figure: some View {
        Text(verbatim: calories)
            .hfStyle(ProfileType.goalFigure)
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var unit: some View {
        Text("kcal mỗi ngày")
            .font(.custom(DSFontName.medium, size: 14, relativeTo: .body))
            .foregroundStyle(Self.onBrand)
            .lineLimit(1)
    }

    /// #BBD8EE — the caption colour on brand blue. Absolute in both appearances
    /// for the reason the brand colours are: it is on the brand fill, which does
    /// not change either.
    private static let onBrand = Color(hex: 0xBBD8EE)

    private var caption: String? {
        guard let originalGoal = model.originalGoal else { return nil }
        guard model.isDirty else {
            return L("Chưa có thay đổi nào. Sửa một trường bất kỳ để xem mục tiêu mới.")
        }
        let previous = AppNumber.int(originalGoal.calories)
        guard let reason = model.lastChanged?.reasonPhrase else {
            return L("Trước đây \(previous) kcal.")
        }
        return L("Trước đây \(previous) kcal · thay đổi vì bạn vừa sửa \(reason).")
    }
}

private extension EditProfileModel.EditField {
    /// Reads into "…vì bạn vừa sửa <phrase>", so each is a lowercase noun.
    var reasonPhrase: String {
        switch self {
        case .sex: L("giới tính")
        case .age: L("tuổi")
        case .height: L("chiều cao")
        case .weight: L("cân nặng hiện tại")
        case .goal: L("hướng mục tiêu")
        case .targetWeight: L("cân nặng mục tiêu")
        case .activity: L("mức vận động")
        }
    }
}

// MARK: - State B (§5)

/// A target weight below the healthy band for the height.
///
/// **Not red, and it does not block "Lưu".** §5 is explicit, and it is the same
/// rule as the over-budget state: the app states a fact, offers an alternative,
/// and leaves the decision where it belongs. The border is 1.5pt neutral grey
/// for exactly that reason — visible enough to be read, quiet enough not to be
/// an alarm.
private struct OutsideSafeRangeNote: View {
    let model: EditProfileModel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            Text("Mục tiêu này thấp hơn mức an toàn thường được khuyến nghị cho chiều cao \(AppNumber.upTo(fractionDigits: 0, model.heightCm)) cm. Bạn có thể vẫn đặt, nhưng nên hỏi bác sĩ trước.")
                .font(.custom(DSFontName.medium, size: 12.5, relativeTo: .footnote))
                .foregroundStyle(DS.textBody)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("editProfile.outsideSafeRange")

            if let suggested = model.suggestedTargetKg {
                Button {
                    model.targetWeightKg = suggested
                } label: {
                    Text("Dùng \(AppNumber.oneDecimal(suggested)) kg thay vào")
                        .hfStyle(ProfileType.inlineAction)
                        .foregroundStyle(DS.blueOnSurface)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editProfile.useSuggestedTarget")
            }
        }
        .padding(DS.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: DS.rCard, style: .continuous)
                .strokeBorder(DS.neutral400, lineWidth: 1.5)
        }
        // The identifiers go on the two leaves, never on this stack: an
        // `accessibilityIdentifier` on a container propagates down and
        // overwrites its children's, so one here would take the suggestion
        // button's name away and leave the only action in the block unnameable.
    }
}

// MARK: - The arithmetic, written out (§5.6)

/// Four lines and a disclaimer.
///
/// It is here because the target is otherwise a number the app asserts. Showing
/// the basal rate, the activity multiplier and the deficit turns it into
/// something the user can check — and, when the safety floor is what actually
/// decided it, says so rather than leaving a figure that stops responding to
/// the form looking broken.
///
/// **Two things §5 draws here are deliberately absent.** The "TỐC ĐỘ" segmented
/// control (0,25 / 0,5 / 0,75 kg a week) has nothing behind it: `WeightGoal`
/// carries one fixed offset per direction, so the three positions would all
/// produce the same target — the broken-control mistake with a number attached.
/// And "Đặt mục tiêu thủ công" opens a screen that does not exist. Both are
/// features, not layout, and belong to a Domain change this screen was not
/// allowed to make.
///
/// The reference page's own arithmetic is worth knowing about before that
/// change is designed: it deducts 320 kcal for 0,5 kg a week, and by its own
/// stated conversion (7.700 kcal ≈ 1 kg) 0,5 kg a week is 550 kcal a day. 320
/// is closer to 0,29 kg. The figures on that page are illustrative.
private struct HowItIsCalculated: View {
    let model: EditProfileModel

    var body: some View {
        SettingsCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Cách tính")
                    .font(.custom(DSFontName.semibold, size: 13, relativeTo: .footnote))
                    .foregroundStyle(DS.textStrong)

                VStack(alignment: .leading, spacing: 7) {
                    line(
                        L("Trao đổi chất cơ bản (BMR)"),
                        AppNumber.int(model.basalMetabolicRate) + " kcal"
                    )
                    line(
                        L("Nhân mức vận động (×\(AppNumber.upTo(fractionDigits: 3, model.activityLevel.multiplier)))"),
                        AppNumber.int(model.totalExpenditure) + " kcal"
                    )
                    line(deltaLabel, model.goal.deltaText)
                    if let floor = floorLine {
                        line(floor, AppNumber.int(model.nutritionGoal.calories) + " kcal")
                    }
                    line(
                        L("Mục tiêu mỗi ngày"),
                        AppNumber.int(model.nutritionGoal.calories) + " kcal",
                        isTotal: true
                    )
                }
                .padding(.top, 10)

                Text("Đây là ước lượng theo công thức Mifflin-St Jeor, không phải chỉ định y tế.")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 11)
            }
            .padding(.horizontal, DS.s4)
            .padding(.vertical, 15)
        }
    }

    private var deltaLabel: String {
        switch model.goal {
        case .lose: L("Trừ để giảm cân")
        case .maintain: L("Không tăng giảm")
        case .gain: L("Cộng để tăng cân")
        }
    }

    /// §5: "Nếu công thức ra thấp hơn thì kẹp lại và **ghi rõ lý do**."
    private var floorLine: String? {
        switch model.floorReason {
        case .basalRate: L("Giữ ở mức trao đổi chất cơ bản")
        case .absoluteMinimum: L("Giữ ở mức tối thiểu an toàn")
        case nil: nil
        }
    }

    private func line(_ key: String, _ value: String, isTotal: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.s3) {
            Text(verbatim: key)
                .font(.custom(DSFontName.regular, size: 12.5, relativeTo: .footnote))
                .foregroundStyle(isTotal ? DS.textStrong : DS.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.s2)
            Text(verbatim: value)
                .font(.custom(DSFontName.semibold, size: 12.5, relativeTo: .footnote))
                .foregroundStyle(isTotal ? DS.textStrong : DS.textBody)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - State D (§5)

/// What saving actually did, said out loud.
///
/// The second sentence is the one that matters and is the reason this is a card
/// rather than a toast: a new target that silently rewrote every past day would
/// be a different app, and HISTORY_SPEC §8 is why it does not — each day keeps
/// the goal it was logged against.
private struct SavedConfirmation: View {
    let goal: NutritionGoal
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0x0F1B27).opacity(0.35).ignoresSafeArea()

            VStack(alignment: .leading, spacing: DS.s3) {
                SettingsCard(padding: DS.s4) {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(DS.green)
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Đã lưu hồ sơ")
                                .font(.custom(DSFontName.semibold, size: 14, relativeTo: .body))
                                .foregroundStyle(DS.textStrong)
                            Text("Mục tiêu mới \(AppNumber.int(goal.calories)) kcal áp dụng từ hôm nay. Những ngày đã ghi giữ nguyên mục tiêu cũ của ngày đó.")
                                .font(.custom(DSFontName.regular, size: 12.5, relativeTo: .footnote))
                                .foregroundStyle(DS.textBody)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text("Quay lại màn Tôi sau một khoảnh khắc, hoặc chạm để về ngay.")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textMuted)
                    .padding(.horizontal, 2)
            }
            .padding(DS.s4)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityIdentifier("editProfile.saved")
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
    }
}
