import SwiftUI

enum DSStatTone {
    case blue, orange, green, neutral

    var color: Color {
        switch self {
        case .blue: DSColor.brandOnSurface
        case .orange: DSPalette.fptOrange
        case .green: Color.dsAdaptive(light: 0x0E9640, dark: 0x47C674)
        case .neutral: DSColor.textStrong
        }
    }
}

/// Headline statistic — big number over a label. Ported from `StatBlock.jsx`.
struct DSStatBlock: View {
    let value: String
    let label: String
    var sublabel: String?
    var tone: DSStatTone = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(DSType.statValue)
                    .kerning(-0.88) // --tracking-tight, −0.02em at 44pt
                    .foregroundStyle(tone.color)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(label)
                    .font(DSType.bodySmallSemibold)
                    .foregroundStyle(DSColor.textStrong)
                    .padding(.top, Space.s2)
            }
            // Read as one phrase — "1,380 kcal eaten" — rather than two
            // disconnected fragments.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(value) \(label)")
            .accessibilityAddTraits(.isStaticText)

            if let sublabel {
                Text(sublabel)
                    .font(DSType.caption)
                    .foregroundStyle(DSColor.textMuted)
                    .padding(.top, 2)
            }
        }
    }
}
