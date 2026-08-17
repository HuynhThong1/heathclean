import SwiftUI

/// Stepper from §6.2 step 1: two 32×32 blue-50 buttons around the value.
struct HFStepper: View {
    let value: Int
    let range: ClosedRange<Int>
    let identifier: String
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: DS.s3) {
            button("minus", enabled: value > range.lowerBound) {
                onChange(max(range.lowerBound, value - 1))
            }
            Text("\(value)")
                .font(.custom(DSFontName.bold, size: 19))
                .foregroundStyle(DS.textStrong)
                .frame(minWidth: 34)
                .accessibilityIdentifier("\(identifier).value")
            button("plus", enabled: value < range.upperBound) {
                onChange(min(range.upperBound, value + 1))
            }
        }
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.blue)
                .frame(width: 32, height: 32)
                .background(DS.blue50, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        // 32pt is the drawn size; the tap area is padded out to the 44pt minimum.
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("\(identifier).\(symbol)")
    }
}

/// Numeric field from §6.2: 66pt wide, right-aligned, 1.5px border, radius 10.
struct HFNumericField: View {
    @Binding var value: Double
    let suffix: String
    let identifier: String

    var body: some View {
        HStack(spacing: DS.s2) {
            TextField("", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.custom(DSFontName.bold, size: 16))
                .foregroundStyle(DS.textStrong)
                .frame(width: 66)
                .padding(.vertical, 8)
                .padding(.horizontal, DS.s2)
                .background(
                    RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                        .strokeBorder(DS.borderDefault, lineWidth: 1.5)
                )
                .accessibilityIdentifier(identifier)

            Text(suffix)
                .hfStyle(HFType.subLabelSemibold)
                .foregroundStyle(DS.textSubtle)
        }
    }
}

/// The same field, for a figure that may legitimately be **unknown**.
///
/// Blank is `nil`, and `nil` is not zero. It exists for fibre, where the two
/// have to stay apart all the way down to the store — a food nobody measured
/// and a food measured at 0 g are different facts, and `FoodItem.fiber` says
/// why that matters. `HFNumericField` cannot express it: it binds a `Double`
/// through `TextField(value:format:)`, which has no representation for an empty
/// field and snaps back to the last value.
///
/// Text-backed for the same reason `DecimalRowField` is — the decimal separator
/// on screen follows the app's language while the keyboard follows the phone's,
/// so both are accepted.
struct HFOptionalNumericField: View {
    @Binding var value: Double?
    let suffix: String
    let identifier: String
    /// What an empty field shows. "—" rather than "0", which is the whole point.
    var placeholder: String = "—"

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DS.s2) {
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.custom(DSFontName.bold, size: 16))
                .foregroundStyle(DS.textStrong)
                .focused($isFocused)
                .frame(width: 66)
                .padding(.vertical, 8)
                .padding(.horizontal, DS.s2)
                .background(
                    RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                        .strokeBorder(DS.borderDefault, lineWidth: 1.5)
                )
                .accessibilityIdentifier(identifier)

            Text(suffix)
                .hfStyle(HFType.subLabelSemibold)
                .foregroundStyle(DS.textSubtle)
        }
        .task { text = formatted }
        .onChange(of: text) {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            // An empty field clears the value rather than leaving the last one
            // behind — otherwise a user who types a figure and deletes it has
            // no way back to "not measured".
            value = trimmed.isEmpty ? nil : Double(trimmed.replacingOccurrences(of: ",", with: "."))
        }
        .onChange(of: isFocused) { if !isFocused { text = formatted } }
    }

    private var formatted: String {
        value.map { AppNumber.upTo(fractionDigits: 1, $0) } ?? ""
    }
}

/// Equal-width segmented control. Selected uses the blue-50 treatment from
/// §6.2; unselected is white with a subtle border.
struct HFSegments<Value: Hashable>: View {
    let options: [(value: Value, label: String, identifier: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: DS.s2) {
            ForEach(options, id: \.value) { option in
                let isSelected = selection == option.value
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .hfStyle(HFType.rowLabel)
                        .foregroundStyle(isSelected ? DS.blue700 : DS.textBody)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(isSelected ? DS.blue50 : DS.surfaceCard)
                        .overlay {
                            RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                                .strokeBorder(
                                    isSelected ? DS.blue : DS.borderSubtle,
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: DS.rControl, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(option.identifier)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

/// Radio card from §6.2 step 2 — ring, label, trailing meta.
struct HFRadioCard: View {
    /// Resolved where it was built: every call site passes an `ActivityLevel`'s
    /// `label`, which a `switch` picks at runtime.
    let title: String
    let meta: String
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.s3) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? DS.blue : DS.neutral300, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle().fill(DS.blue).frame(width: 10, height: 10)
                    }
                }

                HFLabel(verbatim: title)

                Spacer(minLength: DS.s2)

                Text(meta)
                    .font(.custom(DSFontName.semibold, size: 12))
                    .foregroundStyle(DS.textSubtle)
            }
            .padding(.horizontal, DS.s4)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surfaceCard)
            .overlay {
                RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                    .strokeBorder(
                        isSelected ? DS.blue : DS.borderSubtle,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.rControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Macro chip from §6.2 step 4.
struct MacroChip: View {
    let vi: String
    let grams: Double
    let background: Color
    let foreground: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(AppNumber.int(grams)) g")
                .font(.custom(DSFontName.extrabold, size: 20))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(vi)
                .hfStyle(HFType.subLabelSemibold)
                .foregroundStyle(foreground.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.s3)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vi), \(AppNumber.int(grams)) gam")
        .accessibilityAddTraits(.isStaticText)
    }
}

/// The BMI context bar from §6.2 step 4: a gradient across the 14–36 range with
/// a marker at the user's position.
struct BMIScaleBar: View {
    let bmi: Double

    private let lower: Double = 14
    private let upper: Double = 36

    private var position: Double {
        min(max((bmi - lower) / (upper - lower), 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [DS.blue300, DS.green400, DS.orange300, Color(hex: 0xD98A8A)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.neutral900)
                    .frame(width: 4, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.white, lineWidth: 2))
                    .offset(x: geometry.size.width * position - 2)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// The 32×32 back chip from §6.2's onboarding shell, shared by every screen
/// that draws its own header instead of using a navigation bar.
///
/// Drawn at 32pt but padded to a 44pt hit target, per §4.
struct HFBackChip: View {
    var isEnabled = true
    let action: () -> Void

    /// The 44pt target and the shape are **inside** the label, which is the rule
    /// this codebase keeps relearning: outside the `Button` they dress a box the
    /// button does not own, so the chip answered only on the 32pt tile it draws
    /// and the 6pt margin around it was dead.
    ///
    /// It looked fine under test — an automated tap lands dead centre and always
    /// hits — and wrong under a thumb. Worst on §6.8, whose header sits *inside* a
    /// `ScrollView`: a touch that drifts a point or two on a target that small is
    /// read as a scroll and the tap never arrives, which is indistinguishable from
    /// a back button that does nothing.
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEnabled ? DS.textBody : DS.neutral300)
                .frame(width: 32, height: 32)
                .background(
                    DS.surfaceSunken,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Quay lại")
    }
}
