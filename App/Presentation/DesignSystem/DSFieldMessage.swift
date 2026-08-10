import SwiftUI

/// Hint or error text sitting under a field.
///
/// This is the one part of the design system's `Input` that carries over to
/// iOS. The bordered box itself is deliberately not ported — native grouped
/// form rows are the platform idiom and bring Dynamic Type, VoiceOver and
/// keyboard handling for free — but the hint/error line has no native
/// equivalent, and without it a disabled Continue button never explains itself.
///
/// Matches `Input.jsx`: 13pt, 6pt below the field, danger colour for errors.
struct DSFieldMessage: View {
    let text: String
    var isError = false

    var body: some View {
        Text(text)
            .font(DSType.caption)
            .foregroundStyle(isError ? DSColor.danger : DSColor.textSubtle)
            .padding(.top, 2)
            .accessibilityLabel(isError ? "Error: \(text)" : text)
    }
}
