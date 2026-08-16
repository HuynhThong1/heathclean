import Domain
import SwiftUI

/// Portion editor — handoff §6.9. Always shows the model's first estimate, so
/// the correction the user is making is visible rather than implied.
struct PortionEditorSheet: View {
    let food: RecognizedFood
    let onChange: (Double) -> Void
    let onRename: (String) -> Void
    /// Nutrition for a food the database did not have, entered for the portion
    /// currently shown.
    let onSupplyNutrition: (Double, Double, Double, Double) -> Void
    let onRemove: () -> Void
    let onDone: () -> Void

    @State private var name: String = ""
    @State private var grams: Double = 0

    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""

    private let presets: [Double] = [50, 100, 150, 200]

    /// Calories are what makes an item usable; the macros can be left blank.
    private var canSupply: Bool { (Double(caloriesText) ?? 0) > 0 }

    var body: some View {
        // The sheet is a fixed detent, every font in it scales with Dynamic
        // Type, and the footer is the only way to commit or delete the portion —
        // so at larger text sizes "Xoá món" / "Xong" was cut off at the sheet
        // edge with no way to reach it. The body scrolls; the footer is pinned
        // outside the scroll view so it cannot be the part that disappears.
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                editorBody
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
                .padding(.top, DS.s4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 34)
        // The sheet's own backing, not the content's: this sheet also has a fixed
        // detent, so any height the content does not use would otherwise show the
        // system background through — near-black in dark mode.
        .presentationBackground(DS.surfaceCard)
        .onAppear {
            name = food.name
            grams = food.weightGrams
        }
    }

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            Capsule()
                .fill(DS.neutral300)
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)

            HStack(spacing: DS.s2) {
                TextField("Tên món", text: $name)
                    .font(.custom(DSFontName.bold, size: 16))
                    .foregroundStyle(DS.textStrong)
                    .accessibilityIdentifier("portion.name")
                    .onSubmit { onRename(name) }
                Spacer(minLength: DS.s2)
                Text("\(Int((food.confidence * 100).rounded()))%")
                    .font(.custom(DSFontName.semibold, size: 11.5))
                    .foregroundStyle(DS.blue700)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DS.blue50, in: Capsule())
            }

            Text("AI ước lượng ban đầu: \(AppNumber.int(food.originalWeightGrams)) g")
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textSubtle)

            stepper

            HStack(spacing: DS.s2) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        set(preset)
                    } label: {
                        Text("\(Int(preset)) g")
                            .font(.custom(DSFontName.semibold, size: 13))
                            .foregroundStyle(DS.textBody)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(DS.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("portion.preset.\(Int(preset))")
                }
            }

            if !food.isResolved {
                nutritionEntry
            }

        }
    }

    private var footer: some View {
        HStack(spacing: DS.s3) {
            Button("Xoá món") { onRemove() }
                .buttonStyle(.ds(.secondary, size: .large))
                .accessibilityIdentifier("portion.remove")
            Button("Xong") {
                // Applies the nutrition before closing, so what was typed is what
                // takes effect. Only when the food is unresolved and calories were
                // actually entered — supplying zeros would mark an unknown food
                // "resolved" at 0 kcal, which is exactly the silent under-count
                // the unresolved state exists to prevent.
                if !food.isResolved, canSupply {
                    onSupplyNutrition(
                        Double(caloriesText) ?? 0,
                        Double(proteinText) ?? 0,
                        Double(carbsText) ?? 0,
                        Double(fatText) ?? 0
                    )
                }
                onRename(name)
                onDone()
            }
            .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
            .accessibilityIdentifier("portion.done")
        }
    }

    /// Shown only for a food the nutrition database did not have. Without it the
    /// item can never resolve — renaming does not re-look-it-up — and confirming
    /// stays blocked, so the scan would be a dead end.
    private var nutritionEntry: some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HFLabel("Chưa có trong cơ sở dữ liệu")

            Text("Nhập kcal cho \(AppNumber.int(grams)) g đang hiển thị rồi bấm Xong. Đổi khẩu phần sau đó vẫn tính lại đúng.")
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textSubtle)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.s2) {
                nutrientField("kcal", text: $caloriesText, id: "calories")
                nutrientField("Đạm g", text: $proteinText, id: "protein")
                nutrientField("Tinh bột g", text: $carbsText, id: "carbs")
                nutrientField("Béo g", text: $fatText, id: "fat")
            }

            // No "apply" button of its own. There was one, and it was a trap:
            // it sat inside the scroll view below the fields, so the keyboard and
            // the pinned footer hid it — leaving "Xong" as the only button in
            // sight, and "Xong" threw the typed figures away. Two buttons where
            // the first is invisible is worse than one. "Xong" applies them now.
        }
        .padding(DS.s3)
        .background(DS.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func nutrientField(
        _ placeholder: LocalizedStringKey,
        text: Binding<String>,
        id: String
    ) -> some View {
        VStack(spacing: 2) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.custom(DSFontName.bold, size: 15))
                .foregroundStyle(DS.textStrong)
                .frame(height: 44)
                .background(DS.surfaceCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityIdentifier("portion.field.\(id)")
            Text(placeholder)
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textSubtle)
        }
    }

    private var stepper: some View {
        HStack(spacing: DS.s4) {
            stepButton("minus") { set(max(0, grams - 10)) }

            VStack(spacing: 2) {
                Text("\(AppNumber.int(grams)) g")
                    .font(.custom(DSFontName.extrabold, size: 34))
                    .foregroundStyle(DS.textStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("portion.grams")
                Text("\(AppNumber.int(derivedCalories)) kcal")
                    .font(.custom(DSFontName.semibold, size: 12.5))
                    .foregroundStyle(DS.blue)
            }
            .frame(maxWidth: .infinity)

            stepButton("plus") { set(grams + 10) }
        }
        .padding(.vertical, DS.s3)
        .frame(maxWidth: .infinity)
        .background(DS.surfacePage, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Recomputed from the model's original estimate so repeated edits do not
    /// compound (§6.9's scaling rule).
    private var derivedCalories: Double {
        guard food.originalWeightGrams > 0 else { return 0 }
        let perGram = food.calories / max(food.weightGrams, .leastNonzeroMagnitude)
        return perGram * grams
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.blue)
                .frame(width: 44, height: 44)
                .background(DS.surfaceCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DS.borderSubtle, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("portion.\(symbol)")
    }

    private func set(_ value: Double) {
        grams = value
        onChange(value)
    }
}
