import Domain
import SwiftUI

/// Portion editor — handoff §6.9. Always shows the model's first estimate, so
/// the correction the user is making is visible rather than implied.
struct PortionEditorSheet: View {
    let food: RecognizedFood
    let onChange: (Double) -> Void
    let onRename: (String) -> Void
    let onRemove: () -> Void
    let onDone: () -> Void

    @State private var name: String = ""
    @State private var grams: Double = 0

    private let presets: [Double] = [50, 100, 150, 200]

    var body: some View {
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

            Text("AI ước lượng ban đầu: \(VNNumber.int(food.originalWeightGrams)) g")
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

            Spacer(minLength: 0)

            HStack(spacing: DS.s3) {
                Button("Xoá món") { onRemove() }
                    .buttonStyle(.ds(.secondary, size: .large))
                    .accessibilityIdentifier("portion.remove")
                Button("Xong") {
                    onRename(name)
                    onDone()
                }
                .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                .accessibilityIdentifier("portion.done")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 34)
        .background(DS.surfaceCard)
        .onAppear {
            name = food.name
            grams = food.weightGrams
        }
    }

    private var stepper: some View {
        HStack(spacing: DS.s4) {
            stepButton("minus") { set(max(0, grams - 10)) }

            VStack(spacing: 2) {
                Text("\(VNNumber.int(grams)) g")
                    .font(.custom(DSFontName.extrabold, size: 34))
                    .foregroundStyle(DS.textStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("portion.grams")
                Text("\(VNNumber.int(derivedCalories)) kcal")
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
