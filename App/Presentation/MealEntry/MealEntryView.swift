import Domain
import SwiftUI

/// Manual entry. Reached from a dashboard meal row with no items yet, and from
/// meal detail's "Thêm món".
struct MealEntryView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var model: MealEntryModel?

    let type: MealType
    let onSaved: (Double) -> Void
    /// Offered so a user who meant to scan is not stuck typing. `nil` where scan
    /// is not reachable from — the scan flow presents this screen itself, and
    /// offering a way back into the camera from there would just be a loop.
    var onScanInstead: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    form(model: model)
                } else {
                    ProgressView()
                }
            }
            .background(DS.surfacePage)
            .navigationTitle(type.vi)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                        .font(.custom(DSFontName.medium, size: 15))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        Task {
                            guard let model else { return }
                            let total = model.totalCalories
                            if await model.save() {
                                onSaved(total)
                                dismiss()
                            }
                        }
                    }
                    .font(.custom(DSFontName.semibold, size: 15))
                    .disabled(model?.canSave != true)
                    .accessibilityIdentifier("mealEntry.save")
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

        return ScrollView {
            VStack(alignment: .leading, spacing: DS.s4) {
                ForEach(Array($model.drafts.enumerated()), id: \.element.id) { index, $draft in
                    draftCard(index: index, draft: $draft, model: model)
                }

                Button {
                    model.addDraft()
                } label: {
                    Label("Thêm món khác", systemImage: "plus")
                        .font(.custom(DSFontName.semibold, size: 15))
                        .foregroundStyle(DS.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .overlay {
                            RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                                .strokeBorder(DS.borderDefault, lineWidth: 1.5)
                        }
                }
                // Stroke-only overlays do not hit-test where nothing is drawn, so
                // without this the empty thirds either side of the label were
                // dead space on a 52pt-tall button.
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityIdentifier("mealEntry.addFood")

                if let onScanInstead {
                    Button(action: onScanInstead) {
                        Label("Quét ảnh thay vì nhập tay", systemImage: "camera")
                            .font(.custom(DSFontName.semibold, size: 15))
                            .foregroundStyle(DS.orange700)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(
                                DS.orange100,
                                in: RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                            )
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mealEntry.scanInstead")
                }

                totalsCard(model: model)

                if let reason = model.blockedReason {
                    DSFieldMessage(text: reason, isError: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, DS.s4)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
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

    private func draftCard(
        index: Int,
        draft: Binding<MealEntryModel.Draft>,
        model: MealEntryModel
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HStack {
                HFSectionHeader(
                    vi: model.drafts.count > 1 ? "Món \(index + 1)" : "Món ăn",
                    en: "Food"
                )
                if model.drafts.count > 1 {
                    Button {
                        model.removeDrafts(at: IndexSet(integer: index))
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.textSubtle)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mealEntry.removeFood.\(index)")
                    .accessibilityLabel("Xoá món \(index + 1)")
                }
            }

            HFCard(padding: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: DS.s3) {
                        LabelPair(vi: "Tên món", en: "Name")
                        Spacer(minLength: DS.s2)
                        TextField("Ví dụ: Phở bò", text: draft.name)
                            .multilineTextAlignment(.trailing)
                            .font(.custom(DSFontName.medium, size: 15))
                            .foregroundStyle(DS.textStrong)
                            .accessibilityIdentifier("field.food")
                    }
                    .padding(.horizontal, DS.s4)
                    .frame(minHeight: 58)

                    separator
                    numericRow("Khối lượng", "Weight", "g", draft.weightGrams, "field.weight")
                    separator
                    numericRow("Calo", "Calories", "kcal", draft.calories, "field.calories")
                    separator
                    numericRow("Đạm", "Protein", "g", draft.protein, "field.protein")
                    separator
                    numericRow("Tinh bột", "Carbs", "g", draft.carbohydrates, "field.carbs")
                    separator
                    numericRow("Chất béo", "Fat", "g", draft.fat, "field.fat")
                }
            }
        }
    }

    private func numericRow(
        _ vi: String,
        _ en: String,
        _ suffix: String,
        _ value: Binding<Double>,
        _ identifier: String
    ) -> some View {
        HStack(spacing: DS.s3) {
            LabelPair(vi: vi, en: en)
            Spacer(minLength: DS.s2)
            HFNumericField(value: value, suffix: suffix, identifier: identifier)
        }
        .padding(.horizontal, DS.s4)
        .frame(minHeight: 58)
    }

    private var separator: some View {
        Rectangle().fill(DS.borderSubtle).frame(height: 1).padding(.leading, DS.s4)
    }

    private func totalsCard(model: MealEntryModel) -> some View {
        HFCard(padding: DS.s5, radius: DS.rHero, accent: DS.green) {
            VStack(alignment: .leading, spacing: DS.s3) {
                Text("TỔNG BỮA ĂN")
                    .hfStyle(HFType.eyebrow)
                    .foregroundStyle(DS.textSubtle)

                HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
                    Text(VNNumber.int(model.totalCalories))
                        .font(.custom(DSFontName.extrabold, size: 38))
                        .tracking(-1.14)
                        .foregroundStyle(DS.textStrong)
                    Text("kcal")
                        .font(.custom(DSFontName.semibold, size: 15))
                        .foregroundStyle(DS.textMuted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tổng \(VNNumber.int(model.totalCalories)) kcal")
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("mealEntry.total")

                HStack(spacing: DS.s2) {
                    MacroChip(
                        vi: "Đạm", grams: model.totalProtein,
                        background: DS.blue50, foreground: DS.blue700
                    )
                    MacroChip(
                        vi: "Tinh bột", grams: model.totalCarbohydrates,
                        background: DS.orange100, foreground: DS.orange700
                    )
                    MacroChip(
                        vi: "Chất béo", grams: model.totalFat,
                        background: DS.green100, foreground: DS.green700
                    )
                }
            }
        }
    }
}
