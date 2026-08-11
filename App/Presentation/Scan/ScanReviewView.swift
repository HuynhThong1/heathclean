import Domain
import SwiftUI

/// AI review — handoff §6.8. The model's proposal, always correctable, never
/// saved until confirmed.
struct ScanReviewView: View {
    @Bindable var model: ScanModel
    let onRescan: () -> Void
    let onConfirmed: (Double) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.s4) {
                    headerRow
                    explainerPill
                    itemList
                    totalCard
                    if let reason = model.blockedReason {
                        DSFieldMessage(text: reason, isError: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, DS.s3)
                .padding(.bottom, DS.s6)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .background(DS.surfacePage)
        .sheet(item: portionBinding) { food in
            PortionEditorSheet(
                food: food,
                onChange: { model.updateWeight(of: food.id, to: $0) },
                onRename: { model.rename(food.id, to: $0) },
                onSupplyNutrition: { calories, protein, carbs, fat in
                    model.supplyNutrition(
                        for: food.id,
                        calories: calories,
                        protein: protein,
                        carbohydrates: carbs,
                        fat: fat
                    )
                },
                onRemove: {
                    model.remove(food.id)
                    model.editingFoodID = nil
                },
                onDone: { model.editingFoodID = nil }
            )
            // Taller when the nutrition entry is showing, or its Dùng số này
            // button sits below the sheet.
            .presentationDetents([.height(food.isResolved ? 460 : 620)])
            .presentationCornerRadius(DS.rSheet)
        }
    }

    private var portionBinding: Binding<RecognizedFood?> {
        Binding(
            get: { model.editingFood },
            set: { model.editingFoodID = $0?.id }
        )
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .top, spacing: DS.s3) {
            HFBackChip { onCancel() }
                .accessibilityIdentifier("scan.back")

            VStack(alignment: .leading, spacing: 1) {
                Text("Kết quả AI")
                    .font(.custom(DSFontName.bold, size: 18))
                    .foregroundStyle(DS.textStrong)
                Text("AI ANALYSIS · you confirm")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
            }

            Spacer(minLength: DS.s2)

            Button("Quét lại") { onRescan() }
                .font(.custom(DSFontName.semibold, size: 13))
                .foregroundStyle(DS.blue)
                .accessibilityIdentifier("scan.rescan")
        }
    }

    private var explainerPill: some View {
        HStack(alignment: .top, spacing: DS.s2) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.blue700)
            Text("AI nhận diện món và ước lượng khẩu phần. Calo do cơ sở dữ liệu dinh dưỡng tính — hãy sửa khẩu phần nếu chưa đúng.")
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.blue700)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.blue50, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Items

    private var itemList: some View {
        VStack(spacing: 10) {
            ForEach(model.foods) { food in
                Button {
                    model.editingFoodID = food.id
                } label: {
                    ScanItemCard(food: food)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("scan.item.\(food.name)")
            }
        }
    }

    private var totalCard: some View {
        HFCard(padding: DS.s5, radius: 14) {
            VStack(alignment: .leading, spacing: DS.s3) {
                Text("TỔNG ƯỚC TÍNH · ESTIMATED TOTAL")
                    .hfStyle(HFType.eyebrow)
                    .foregroundStyle(DS.textSubtle)

                Text("\(VNNumber.int(model.result?.totalCalories ?? 0)) kcal")
                    .font(.custom(DSFontName.extrabold, size: 30))
                    .tracking(-0.6)
                    .foregroundStyle(DS.blue)
                    .accessibilityIdentifier("scan.total")

                HStack(spacing: DS.s2) {
                    MacroChip(
                        vi: "Đạm", grams: model.result?.totalProtein ?? 0,
                        background: DS.blue50, foreground: DS.blue700
                    )
                    MacroChip(
                        vi: "Tinh bột", grams: model.result?.totalCarbohydrates ?? 0,
                        background: DS.orange100, foreground: DS.orange700
                    )
                    MacroChip(
                        vi: "Chất béo", grams: model.result?.totalFat ?? 0,
                        background: DS.green100, foreground: DS.green700
                    )
                }

                // §6.8 names USDA and the Vietnamese DB. Only the latter is
                // real today, so claiming USDA would be false.
                Text("Nguồn: CSDL món Việt · \(model.result?.provider ?? "—")")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: DS.s3) {
            VStack(spacing: 1) {
                Text(model.type.vi)
                    .font(.custom(DSFontName.bold, size: 13))
                    .foregroundStyle(DS.textStrong)
                Text("bữa ăn")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
            }
            .frame(width: 104)

            Button("Xác nhận bữa ăn") {
                Task {
                    if let calories = await model.confirm() { onConfirmed(calories) }
                }
            }
            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
            .disabled(!model.canConfirm)
            .accessibilityIdentifier("scan.confirm")
        }
        .padding(.horizontal, 20)
        .padding(.top, DS.s3)
        .padding(.bottom, DS.s2)
        .background(DS.surfaceCard)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.borderSubtle).frame(height: 1)
        }
    }
}

// MARK: - Item card

private struct ScanItemCard: View {
    let food: RecognizedFood

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(food.name)
                        .font(.custom(DSFontName.bold, size: 15))
                        .tracking(-0.15)
                        .foregroundStyle(DS.textStrong)
                    if let nameEn = food.nameEn {
                        Text(nameEn)
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(DS.textSubtle)
                    }
                }
                Spacer(minLength: DS.s2)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(VNNumber.int(food.calories))
                        .font(.custom(DSFontName.bold, size: 16))
                        .foregroundStyle(DS.textStrong)
                    Text("kcal")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                }
            }

            HStack(spacing: DS.s2) {
                Text("\(VNNumber.int(food.weightGrams)) g")
                    .font(.custom(DSFontName.semibold, size: 12.5))
                    .foregroundStyle(DS.textBody)
                    .padding(.horizontal, DS.s2)
                    .padding(.vertical, 3)
                    .background(DS.surfaceSunken, in: Capsule())

                confidenceBadge

                Spacer(minLength: DS.s1)

                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.neutral400)
            }

            if food.isResolved {
                Text("Đ \(VNNumber.int(food.protein)) · TB \(VNNumber.int(food.carbohydrates)) · B \(VNNumber.int(food.fat))")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
            } else {
                // Points at the portion editor, where nutrition can be entered.
                // It used to say "sửa tên", which does not resolve anything.
                Text("Chưa có trong cơ sở dữ liệu — mở món này để nhập dinh dưỡng.")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.orange700)
            }
        }
        .padding(DS.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surfaceCard)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    food.isLowConfidence || !food.isResolved ? DS.orange300 : DS.borderSubtle,
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(food.name), \(VNNumber.int(food.weightGrams)) gam, \(VNNumber.int(food.calories)) kcal, \(confidenceText)"
        )
    }

    private var percent: Int { Int((food.confidence * 100).rounded()) }

    private var confidenceText: String {
        food.isLowConfidence ? "Nên kiểm tra \(percent)%" : "Tin cậy \(percent)%"
    }

    private var confidenceBadge: some View {
        Text(confidenceText)
            .font(.custom(DSFontName.semibold, size: 11.5))
            .foregroundStyle(badgeForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeBackground, in: Capsule())
    }

    private var badgeBackground: Color {
        if food.isLowConfidence { return DS.orange100 }
        return food.confidence >= 0.90 ? DS.green100 : DS.blue50
    }

    private var badgeForeground: Color {
        if food.isLowConfidence { return DS.orange700 }
        return food.confidence >= 0.90 ? DS.green700 : DS.blue700
    }
}
