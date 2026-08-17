import Domain
import SwiftUI

/// Meal detail — handoff §6.10.
struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var model: MealDetailModel
    let onAddMore: () -> Void
    let onChanged: () -> Void
    let onDeleted: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.s4) {
                // Above the numbers, as on the day sheet — the picture is what
                // identifies the meal, and this screen is where someone came to
                // look at it. Draws nothing for a meal typed in by hand.
                MealPhotoGrid(photos: model.photos, identifierPrefix: "mealDetail.photo")
                heroCard
                itemsCard
                if let note = summaryNote {
                    GrayNote(verbatim: note)
                }
                deleteButton
            }
            .padding(.horizontal, 20)
            .padding(.top, DS.s4)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(DS.surfacePage)
        .navigationTitle(model.type.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Thêm món") { onAddMore() }
                    .font(.custom(DSFontName.semibold, size: 15))
                    .accessibilityIdentifier("mealDetail.addMore")
            }
        }
        .sheet(isPresented: $model.isConfirmingDelete) {
            HFDestructiveConfirm(
                title: L("Xoá cả \(model.type.label.lowercased())?"),
                message: L("Tất cả \(model.items.count) món trong bữa này sẽ bị xoá. Thao tác không thể hoàn tác."),
                confirmLabel: L("Xoá cả bữa ăn"),
                onConfirm: {
                    model.isConfirmingDelete = false
                    Task {
                        if await model.delete() {
                            onDeleted()
                            dismiss()
                        }
                    }
                },
                onCancel: { model.isConfirmingDelete = false }
            )
        }
        .sheet(item: $model.itemPendingRemoval) { item in
            HFDestructiveConfirm(
                title: L("Xoá “\(item.name)”?"),
                // Says what is left afterwards, because the alternative — deleting
                // the last food — quietly removes the whole meal.
                message: model.items.count > 1
                    ? L("Bữa ăn còn lại \(model.items.count - 1) món.")
                    : L("Đây là món cuối cùng, nên cả bữa ăn sẽ bị xoá."),
                confirmLabel: L("Xoá món này"),
                onConfirm: {
                    model.itemPendingRemoval = nil
                    Task {
                        switch await model.removeItem(item) {
                        case .itemRemoved:
                            onChanged()
                        case .mealDeleted:
                            onDeleted()
                            dismiss()
                        case .unchanged:
                            break
                        }
                    }
                },
                onCancel: { model.itemPendingRemoval = nil }
            )
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
                            Text(AppNumber.int(model.totalCalories))
                                .font(.custom(DSFontName.extrabold, size: 38))
                                .tracking(-1.14)
                                .foregroundStyle(DS.textStrong)
                            Text("kcal")
                                .font(.custom(DSFontName.semibold, size: 15))
                                .foregroundStyle(DS.textMuted)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Tổng bữa ăn \(AppNumber.int(model.totalCalories)) kcal")
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

                // A fourth chip only when this meal has a figure. Three chips
                // and a gap would be worse than three chips, and a "0 g" chip
                // would be a claim about food nobody measured.
                if let fiber = model.totalFiber {
                    HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
                        HFLabel("Chất xơ")
                        Spacer(minLength: DS.s2)
                        Text(verbatim: "\(AppNumber.int(fiber)) g")
                            .hfStyle(HFType.rowValue)
                            .foregroundStyle(DS.textStrong)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isStaticText)

                    if model.itemsMissingFiber > 0 {
                        Text("\(model.itemsMissingFiber) món trong bữa này chưa có số liệu chất xơ.")
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(DS.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
            HFSectionHeader("Món đã ghi")
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
                Text("\(AppNumber.int(item.calories)) kcal")
                    .font(.custom(DSFontName.bold, size: 14.5))
                    .foregroundStyle(DS.textStrong)
                Text("\(AppNumber.int(item.weightGrams)) g")
                    .font(.custom(DSFontName.regular, size: 11))
                    .foregroundStyle(DS.textSubtle)
            }

            // An explicit button rather than swipe-to-delete: these rows live in a
            // `VStack` inside a card, not a `List`, so there is no swipe to hook —
            // and a hidden gesture is a poor way to offer the one action that
            // cannot be undone.
            Button {
                model.itemPendingRemoval = item
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.textSubtle)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mealDetail.removeItem")
            .accessibilityLabel("Xoá \(item.name)")
        }
        .padding(.horizontal, DS.s4)
        .frame(minHeight: 58)
        // `.contain` rather than `.ignore`: the row now holds a button, and
        // collapsing it into one static element would hide the only way to delete
        // a food from VoiceOver entirely.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(item.name), \(AppNumber.int(item.calories)) kcal, \(AppNumber.int(item.weightGrams)) gam"
        )
    }

    private var summaryNote: String? {
        guard model.totalCalories > 0 else { return nil }
        let share = L("Bữa này chiếm \(model.budgetSharePercent)% ngân sách calo hôm nay.")
        guard let time = model.loggedAtText else { return share }
        return L("\(share) Ghi lúc \(time).")
    }

    private var deleteButton: some View {
        // `.buttonStyle(.plain)` and the styling *inside* the label, both for the
        // same reason: the default borderless style tints its own label, so an
        // outer `.foregroundStyle` lost and §6.10's quiet grey action drew in
        // system accent blue — the loudest thing on the screen. `.contentShape`
        // because a stroke-only overlay hit-tests nowhere it has not drawn, so
        // taps on the empty thirds of a 52pt box did nothing.
        Button {
            model.isConfirmingDelete = true
        } label: {
            Text("Xoá bữa ăn này")
                .font(.custom(DSFontName.semibold, size: 15))
                .foregroundStyle(DS.textMuted)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                        .strokeBorder(DS.borderDefault, lineWidth: 1.5)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
