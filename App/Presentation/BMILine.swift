import Domain
import SwiftUI

/// BMI value plus its category badge, read as one phrase by VoiceOver.
/// Shared by onboarding's targets card and the dashboard's health context row.
struct BMILine: View {
    let bmi: BMI

    var body: some View {
        HStack(spacing: Space.s3) {
            Text("BMI")
                .font(DSType.body)
                .foregroundStyle(DSColor.textBody)
            Spacer(minLength: Space.s2)
            Text(bmi.value, format: .number.precision(.fractionLength(1)))
                .font(DSType.bodySemibold)
                .foregroundStyle(DSColor.textStrong)
            DSBadge(text: bmi.category.label, tone: bmi.category.badgeTone)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "BMI, \(bmi.value.formatted(.number.precision(.fractionLength(1)))), \(bmi.category.label)"
        )
        .accessibilityAddTraits(.isStaticText)
    }
}
