import SwiftUI

/// A label/value line — the repeated shape across macros, meal totals and
/// history rows.
///
/// `LabeledContent` merges its two sides into a single accessibility element
/// only when it is given a plain string label inside a `Form`/`List`. These
/// rows use styled label views and some sit inside cards, so the merge is
/// declared explicitly — otherwise VoiceOver reads "Protein" and "112 g" as
/// two unrelated items.
struct DSValueRow: View {
    let name: String
    let value: String
    var valueFont: Font = DSType.bodySmallMedium
    var valueColor: Color = DSColor.textMuted

    var body: some View {
        HStack(spacing: Space.s3) {
            Text(name)
                .font(DSType.body)
                .foregroundStyle(DSColor.textBody)
            Spacer(minLength: Space.s2)
            Text(value)
                .font(valueFont)
                .foregroundStyle(valueColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(value)")
        .accessibilityAddTraits(.isStaticText)
    }
}
