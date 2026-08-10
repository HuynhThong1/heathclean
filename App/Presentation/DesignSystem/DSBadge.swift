import SwiftUI

enum DSBadgeTone {
    case blue, orange, green, neutral, danger
}

enum DSBadgeVariant {
    case soft, solid
}

/// Small status / category pill. Ported from `Badge.jsx`.
///
/// The `soft` backgrounds upstream are 100-level tints, which glow on a dark
/// surface — so in dark appearance they resolve to a deep tint of the same hue
/// with light text instead. `solid` needs no such adjustment.
struct DSBadge: View {
    let text: String
    var tone: DSBadgeTone = .blue
    var variant: DSBadgeVariant = .soft

    var body: some View {
        Text(text)
            .font(DSType.badge)
            .kerning(0.12)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }

    private var background: Color {
        switch (tone, variant) {
        case (.blue, .soft): Color.dsAdaptive(light: 0xE2F0FB, dark: 0x0E2C46)
        case (.blue, .solid): DSPalette.fptBlue
        case (.orange, .soft): Color.dsAdaptive(light: 0xFDEADC, dark: 0x42230D)
        case (.orange, .solid): DSPalette.fptOrange
        case (.green, .soft): Color.dsAdaptive(light: 0xE4F7EB, dark: 0x0C3B1D)
        case (.green, .solid): DSPalette.green600
        case (.neutral, .soft): Color.dsAdaptive(light: 0xE9EEF2, dark: 0x24313E)
        case (.neutral, .solid): DSPalette.neutral700
        case (.danger, .soft): Color.dsAdaptive(light: 0xFBE3E1, dark: 0x461513)
        case (.danger, .solid): DSPalette.danger
        }
    }

    private var foreground: Color {
        switch variant {
        case .solid:
            return DSColor.textOnBrand
        case .soft:
            switch tone {
            case .blue: return Color.dsAdaptive(light: 0x004E8C, dark: 0x86BEEA)
            case .orange: return Color.dsAdaptive(light: 0xC4520E, dark: 0xFBB183)
            case .green: return Color.dsAdaptive(light: 0x0A7D34, dark: 0x83DAA1)
            case .neutral: return Color.dsAdaptive(light: 0x35485A, dark: 0xC0CAD4)
            case .danger: return Color.dsAdaptive(light: 0xD5342B, dark: 0xF0928C)
            }
        }
    }
}
