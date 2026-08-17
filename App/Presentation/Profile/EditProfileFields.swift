import Domain
import SwiftUI

/// The two field kinds PROFILE_SPEC §5's table names: a decimal-pad number, and
/// a choice that opens a sheet. No steppers and no wheel pickers, both ruled out
/// by name.

// MARK: - Numbers

/// A number written straight into the row, right-aligned, with its unit beside
/// it.
///
/// **It edits a `String`, not the `Double`.** `TextField(value:format:)` parses
/// against the format's locale, and the decimal separator on screen comes from
/// the *language* the app is drawn in while the key the user is offered comes
/// from the **phone's** keyboard — so a Vietnamese UI on an English phone offers
/// "." to a parser that wants ",", and the field silently snaps back to its old
/// value on every edit. Accepting both separators is the only version that works
/// in all four combinations.
///
/// Grouping separators are not stripped, on purpose: in `vi_VN` the group
/// separator is "." and the decimal is ",", so treating "." as grouping would
/// read a typed "98.5" as 985. Every field here is bounded well under a
/// thousand, where grouping never appears.
struct DecimalRowField: View {
    @Binding var value: Double
    let unit: String
    let identifier: String
    /// The row's own title. The field is a separate accessibility element — the
    /// row cannot merge around a control — so without this VoiceOver announces
    /// a number with no name.
    let accessibilityLabel: String
    var fractionDigits = 1

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .hfStyle(ProfileType.rowValueStrong)
                .foregroundStyle(DS.textStrong)
                .focused($isFocused)
                .frame(minWidth: 56)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(Text(verbatim: "\(accessibilityLabel), \(unit)"))

            Text(verbatim: unit)
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textMuted)
        }
        .task { text = formatted }
        // While the field has focus the user's keystrokes are the truth; a
        // reformat here would fight the caret mid-word ("98," becoming "98,0").
        .onChange(of: value) { if !isFocused { text = formatted } }
        .onChange(of: text) {
            if let parsed = Self.parse(text) { value = parsed }
        }
        .onChange(of: isFocused) { if !isFocused { text = formatted } }
    }

    private var formatted: String {
        AppNumber.upTo(fractionDigits: fractionDigits, value)
    }

    static func parse(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}

/// The same, for a whole number.
///
/// `unit` is optional because the age field has none: its unit word in
/// Vietnamese is "tuổi", which is also the noun the goal card uses to say
/// *which* field was edited — and one catalog key cannot be both "years" after
/// a number and "age" inside a sentence. The row label carries the meaning
/// instead. `AppDate.weekdayNarrow` records the same trap.
struct IntegerRowField: View {
    @Binding var value: Int
    var unit: String?
    let identifier: String
    let accessibilityLabel: String

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .hfStyle(ProfileType.rowValueStrong)
                .foregroundStyle(DS.textStrong)
                .focused($isFocused)
                .frame(minWidth: 40)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(Text(verbatim: accessibilityLabel))

            if let unit {
                Text(verbatim: unit)
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textMuted)
            }
        }
        .task { text = String(value) }
        .onChange(of: value) { if !isFocused { text = String(value) } }
        .onChange(of: text) {
            if let parsed = Int(text.trimmingCharacters(in: .whitespaces)) { value = parsed }
        }
        .onChange(of: isFocused) { if !isFocused { text = String(value) } }
    }
}

// MARK: - Choices

struct ChoiceOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    /// §5's state A: "mỗi dòng có mô tả để không phải đoán". A list of four
    /// activity levels with no description asks the user to guess what "vừa"
    /// means, and they will guess differently from the formula.
    var detail: String?
    /// A row with a description is one accessibility element whose label is
    /// both lines joined, so nothing can match it on its title alone — the
    /// `LabeledContent` trap CLAUDE.md records, in a different shape. Query by
    /// identifier.
    let identifier: String

    var id: Value { value }
}

/// §5's state **A** — the sheet every choice field opens.
///
/// `.medium` detent, rows at least 44pt, a description under each, and a blue
/// tick on the right. Explicitly not a wheel picker: a wheel hides every option
/// but one and gives no room for the descriptions that make the choice
/// answerable.
struct ChoiceSheet<Value: Hashable>: View {
    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let options: [ChoiceOption<Value>]
    @Binding var selection: Value
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .hfStyle(HFType.sectionHead)
                .foregroundStyle(DS.textStrong)
                .padding(.horizontal, DS.s4)
                // A visible drag indicator is drawn by the presentation
                // controller inside the sheet's own top ~10pt, over whatever the
                // content puts there — so a title needs about 24pt above it.
                .padding(.top, 24)
                .padding(.bottom, DS.s3)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        if index > 0 { SettingsDivider() }
                        row(option)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // A sheet taller than its content shows its own backing above and below,
        // which is near-white in light and a black band in dark. Colour the
        // sheet, not the content.
        .presentationBackground(DS.surfaceCard)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier(identifier)
    }

    private func row(_ option: ChoiceOption<Value>) -> some View {
        let isSelected = selection == option.value

        return Button {
            selection = option.value
            dismiss()
        } label: {
            HStack(spacing: DS.s3) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: option.title)
                        .hfStyle(HFType.rowLabel)
                        .foregroundStyle(DS.textStrong)
                    if let detail = option.detail {
                        Text(verbatim: detail)
                            .hfStyle(HFType.subLabel)
                            .foregroundStyle(DS.textMuted)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.blueOnSurface)
                }
            }
            .padding(.horizontal, DS.s4)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(option.identifier)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Domain copy for the sheets

extension ActivityLevel {
    /// The name on its own. `label` folds the frequency into the same string
    /// ("Nhẹ — 1–3 ngày/tuần") because onboarding's radio cards have one line;
    /// §5's sheet has two, and its own tests match on `label`.
    var shortLabel: String {
        switch self {
        case .sedentary: L("Ít vận động")
        case .light: L("Vận động nhẹ")
        case .moderate: L("Vận động vừa")
        case .active: L("Vận động nhiều")
        case .veryActive: L("Vận động rất nhiều")
        }
    }

    var detail: String {
        switch self {
        case .sedentary: L("Ngồi làm việc, đi lại nhẹ")
        case .light: L("Tập 1–3 buổi mỗi tuần")
        case .moderate: L("Tập 3–5 buổi mỗi tuần")
        case .active: L("Tập 6–7 buổi mỗi tuần")
        case .veryActive: L("Công việc thể lực, hoặc tập hai buổi mỗi ngày")
        }
    }
}

extension WeightGoal {
    var editDetail: String {
        switch self {
        case .lose: L("Ăn ít hơn mức tiêu hao mỗi ngày.")
        case .maintain: L("Giữ cân nặng hiện tại.")
        case .gain: L("Ăn nhiều hơn mức tiêu hao mỗi ngày.")
        }
    }
}
