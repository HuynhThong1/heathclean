import SwiftUI

// Verbatim from design_handoff_healthclean/README.md §9. Values come from that
// bundle's tokens/colors.css and tokens/semantic.css.
//
// Note these differ slightly from `DSPalette`/`DSColor`, which came from an
// earlier sync of the claude.ai Design project. `DS.*` is the palette new work
// uses; see CLAUDE.md.

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: 1)
    }
}

enum DS {
    // Brand
    static let blue   = Color(hex: 0x0062B0)   // primary
    static let orange = Color(hex: 0xF37021)   // single accent: scan
    static let green  = Color(hex: 0x12B24C)   // growth / success

    // Blue ramp
    static let blue50  = Color(hex: 0xEDF5FC)
    static let blue100 = Color(hex: 0xD3E7F8)
    static let blue200 = Color(hex: 0xA7CFF1)
    static let blue300 = Color(hex: 0x6FB0E7)
    static let blue500 = Color(hex: 0x0071CC)
    static let blue700 = Color(hex: 0x004E8C)

    // Orange / green ramps
    static let orange100 = Color(hex: 0xFDE8DA)
    static let orange300 = Color(hex: 0xF9B183)
    static let orange700 = Color(hex: 0xC2540F)
    static let green100  = Color(hex: 0xDCF5E5)
    static let green400  = Color(hex: 0x3ECB72)
    static let green600  = Color(hex: 0x0E9F43)
    static let green700  = Color(hex: 0x0B7A34)

    // Cool neutrals
    static let neutral150 = Color(hex: 0xE9EDF2)
    static let neutral200 = Color(hex: 0xDCE2EA)
    static let neutral300 = Color(hex: 0xC3CCD8)
    static let neutral400 = Color(hex: 0x9AA7B8)
    static let neutral600 = Color(hex: 0x5B6878)
    static let neutral700 = Color(hex: 0x44505F)
    static let neutral900 = Color(hex: 0x0F1B27)

    // Semantic
    static let surfacePage   = Color(hex: 0xF4F7FA)
    static let surfaceCard   = Color.white
    static let surfaceSunken = Color(hex: 0xEDF1F5)
    static let textStrong    = Color(hex: 0x0F1B27)
    static let textBody      = Color(hex: 0x2B3947)
    static let textMuted     = Color(hex: 0x5B6878)
    static let textSubtle    = Color(hex: 0x8794A6)
    static let borderSubtle  = Color(hex: 0xE9EDF2)
    static let borderDefault = Color(hex: 0xDCE2EA)
    static let danger        = Color(hex: 0xD64545)

    // Radii
    static let rControl: CGFloat = 10
    static let rCard: CGFloat = 16
    static let rHero: CGFloat = 20
    static let rSheet: CGFloat = 24

    // Spacing (8pt grid, 4pt half-steps)
    static let s1: CGFloat = 4, s2: CGFloat = 8, s3: CGFloat = 12
    static let s4: CGFloat = 16, s5: CGFloat = 20, s6: CGFloat = 24

    // Motion
    static let durFast = 0.12
    static let durBase = 0.20
    static let ease = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.20)
}
