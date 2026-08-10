import Domain
import SwiftUI

/// Meal detail — handoff §6.10.
struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var model: MealDetailModel
    let onAddMore: () -> Void
    let onDeleted: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.s4) {
                heroCard
                itemsCard
                if let note = summaryNote {
                    GrayNote(text: note)
                }
                deleteButton
            }
            .padding(.horizontal, 20)
            .padding(.top, DS.s4)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(DS.surfacePage)
        .navigationTitle(model.type.vi)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Thêm món") { onAddMore() }
                    .font(.custom(DSFontName.semibold, size: 15))
                    .accessibilityIdentifier("mealDetail.addMore")
            }
        }
        .confirmationDialog(
            "Xoá bữa ăn này?",
            isPresented: $model.isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Xoá bữa ăn", role: .destructive) {
                Task {
                    if await model.delete() {
                        onDeleted()
                        dismiss()
                    }
                }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Thao tác này không thể hoàn tác.")
        }
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

    // MARK: Hero

    private var heroCard: some View {
        HFCard(padding: DS.s5, radius: DS.rHero, accent: model.type.accentColor) {
            VStack(alignment: .leading, spacing: DS.s4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.s1) {
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
                        .accessibilityLabel("Tổng bữa ăn \(VNNumber.int(model.totalCalories)) kcal")
                        .accessibilityAddTraits(.isStaticText)
                        .accessibilityIdentifier("mealDetail.total")
                    }

                    Spacer(minLength: DS.s3)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(model.budgetSharePercent)%")
                            .font(.custom(DSFontName.bold, size: 15))
                            .foregroundStyle(DS.blue)
                        Text("ngân sách ngày")
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(DS.textSubtle)
                    }
                }

                macroEnergyBar

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

    /// Split by kcal contribution, not by grams — 1 g of fat carries more than
    /// twice the energy of 1 g of protein, so a gram split would misread.
    private var macroEnergyBar: some View {
        let shares = model.macroEnergyShares
        return GeometryReader { geometry in
            HStack(spacing: 2) {
                Capsule().fill(DS.blue)
                    .frame(width: max(0, geometry.size.width * shares.protein - 2))
                Capsule().fill(DS.orange)
                    .frame(width: max(0, geometry.size.width * shares.carbs - 2))
                Capsule().fill(DS.green)
                    .frame(width: max(0, geometry.size.width * shares.fat))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Capsule().fill(DS.neutral150))
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    // MARK: Items

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HFSectionHeader(vi: "Món đã ghi", en: "Items")
            HFCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        itemRow(item)
                        if index < model.items.count - 1 {
                            Rectangle().fill(DS.borderSubtle)
                                .frame(height: 1)
                                .padding(.leading, DS.s4)
                        }
                    }
                }
            }
        }
    }

    private func itemRow(_ item: FoodItem) -> some View {
        HStack(alignment: .center, spacing: DS.s3) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .hfStyle(HFType.rowLabel)
                    .foregroundStyle(DS.textStrong)
                // No AI yet, so everything here was typed by hand.
                Text(item.aiConfidence == nil ? "Nhập tay" : "AI")
                    .font(.custom(DSFontName.regular, size: 11))
                    .foregroundStyle(DS.textSubtle)
            }
            Spacer(minLength: DS.s2)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(VNNumber.int(item.calories)) kcal")
                    .font(.custom(DSFontName.bold, size: 14.5))
                    .foregroundStyle(DS.textStrong)
                Text("\(VNNumber.int(item.weightGrams)) g")
                    .font(.custom(DSFontName.regular, size: 11))
                    .foregroundStyle(DS.textSubtle)
            }
        }
        .padding(.horizontal, DS.s4)
        .frame(minHeight: 58)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(item.name), \(VNNumber.int(item.calories)) kcal, \(VNNumber.int(item.weightGrams)) gam"
        )
    }

    private var summaryNote: String? {
        guard model.totalCalories > 0 else { return nil }
        let share = "Bữa này chiếm \(model.budgetSharePercent)% ngân sách calo hôm nay."
        guard let time = model.loggedAtText else { return share }
        return "\(share) Ghi lúc \(time)."
    }

    private var deleteButton: some View {
        Button("Xoá bữa ăn này") {
            model.isConfirmingDelete = true
        }
        .font(.custom(DSFontName.semibold, size: 15))
        .foregroundStyle(DS.textMuted)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .overlay {
            RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                .strokeBorder(DS.borderDefault, lineWidth: 1.5)
        }
        .accessibilityIdentifier("mealDetail.delete")
    }
}

extension MealType {
    /// Top accent bar colour for the detail hero (§6.10).
    var accentColor: Color {
        switch self {
        case .breakfast: DS.orange
        case .lunch: DS.blue
        case .snack: DS.green
        case .dinner: DS.blue500
        }
    }
}
