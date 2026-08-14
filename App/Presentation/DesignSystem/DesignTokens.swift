import SwiftUI

// Verbatim from design_handoff_healthclean/README.md §9. Values come from that
// bundle's tokens/colors.css and tokens/semantic.css.
//
// Note these differ slightly from `DSPalette`/`DSColor`, which came from an
// earlier sync of the claude.ai Design project. `DS.*` is the palette new work
// uses; see CLAUDE.md.
//
// # The dark side of this file is invented
//
// The handoff, like the FPT IS design system it comes from, is **light-only** —
// every value below that says `dark:` was derived here, the same way `DSColor`'s
// dark palette was. Replace the lot if the brand team ever publishes real ones.
//
// How they were derived, so a replacement can be judged against the intent:
//
// - Surfaces invert but do not go black. Page #0B1219, cards lifted to #131E29,
//   sunken *below* the page at #0E1720 — on dark, "sunken" has to read as
//   recessed, which a lighter value cannot do.
// - Text keeps its four-step hierarchy, mirrored: strong is near-white, subtle
//   is the faintest that still passes on #131E29.
// - **The tint ramps flip role.** `blue50`…`blue200` are backgrounds in light and
//   would be near-white blocks on dark, so they become deep tints; `blue700`,
//   `orange700`, `green700` are *text on those tints*, so they become light.
//   Getting this backwards is the single easiest way to make a screen
//   unreadable, and it is why the ramps are not simply left absolute.
// - Neutral tracks (`neutral150`…`neutral300`) are chart tracks and dividers.
//   They lighten just enough to separate from the card without competing with
//   the data drawn on them.
// - `neutral900` is §6.14's toast fill. It lifts to #22303D on dark so the toast
//   still reads as raised rather than dissolving into the page.
// - The three brand colours are **absolute**. §4 says blue leads, orange is the
//   scan action alone, green is growth — an identity that changed with the
//   appearance would not be an identity.

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
    // Brand — absolute in both appearances (§4).
    static let blue   = Color(hex: 0x0062B0)   // primary
    static let orange = Color(hex: 0xF37021)   // single accent: scan
    static let green  = Color(hex: 0x12B24C)   // growth / success

    /// Brand blue where it is drawn as **text or an icon** rather than a fill.
    /// #0062B0 on a #131E29 card is roughly 2.6:1, so the dark side lifts it;
    /// as a fill the brand value still applies.
    static let blueOnSurface = Color.dsAdaptive(light: 0x0062B0, dark: 0x86BEEA)

    // Blue ramp — 50…200 are tint *backgrounds*, 700 is *text* on them.
    static let blue50  = Color.dsAdaptive(light: 0xEDF5FC, dark: 0x0E2C46)
    static let blue100 = Color.dsAdaptive(light: 0xD3E7F8, dark: 0x143A58)
    static let blue200 = Color.dsAdaptive(light: 0xA7CFF1, dark: 0x1F4C70)
    static let blue300 = Color.dsAdaptive(light: 0x6FB0E7, dark: 0x2E6A94)
    static let blue500 = Color.dsAdaptive(light: 0x0071CC, dark: 0x1A7CCB)
    static let blue700 = Color.dsAdaptive(light: 0x004E8C, dark: 0x86BEEA)

    // Orange / green ramps — same flip: 100 is a background, 700 is text.
    static let orange100 = Color.dsAdaptive(light: 0xFDE8DA, dark: 0x3A2113)
    static let orange300 = Color.dsAdaptive(light: 0xF9B183, dark: 0x8A4A1E)
    static let orange700 = Color.dsAdaptive(light: 0xC2540F, dark: 0xF9B183)
    static let green100  = Color.dsAdaptive(light: 0xDCF5E5, dark: 0x12301F)
    static let green400  = Color.dsAdaptive(light: 0x3ECB72, dark: 0x3ECB72)
    static let green600  = Color.dsAdaptive(light: 0x0E9F43, dark: 0x2FD46F)
    static let green700  = Color.dsAdaptive(light: 0x0B7A34, dark: 0x86E0A5)

    // Cool neutrals — chart tracks, dividers, chips.
    static let neutral150 = Color.dsAdaptive(light: 0xE9EDF2, dark: 0x1E2A36)
    static let neutral200 = Color.dsAdaptive(light: 0xDCE2EA, dark: 0x263442)
    static let neutral300 = Color.dsAdaptive(light: 0xC3CCD8, dark: 0x3A4A5A)
    static let neutral400 = Color.dsAdaptive(light: 0x9AA7B8, dark: 0x7C8B9C)
    static let neutral600 = Color.dsAdaptive(light: 0x5B6878, dark: 0x94A3B2)
    static let neutral700 = Color.dsAdaptive(light: 0x44505F, dark: 0xB4C0CC)
    /// §6.14's toast fill, which is why the dark value *lifts* rather than
    /// darkens — a #0F1B27 pill on a #0B1219 page is invisible.
    static let neutral900 = Color.dsAdaptive(light: 0x0F1B27, dark: 0x22303D)

    // Semantic
    static let surfacePage   = Color.dsAdaptive(light: 0xF4F7FA, dark: 0x0B1219)
    static let surfaceCard   = Color.dsAdaptive(light: 0xFFFFFF, dark: 0x131E29)
    /// Below the page on dark, not above it — "sunken" has to read as recessed.
    static let surfaceSunken = Color.dsAdaptive(light: 0xEDF1F5, dark: 0x0E1720)
    static let textStrong    = Color.dsAdaptive(light: 0x0F1B27, dark: 0xF2F5F8)
    static let textBody      = Color.dsAdaptive(light: 0x2B3947, dark: 0xDDE4EA)
    static let textMuted     = Color.dsAdaptive(light: 0x5B6878, dark: 0x9FADBB)
    static let textSubtle    = Color.dsAdaptive(light: 0x8794A6, dark: 0x8494A5)
    static let borderSubtle  = Color.dsAdaptive(light: 0xE9EDF2, dark: 0x1E2A36)
    static let borderDefault = Color.dsAdaptive(light: 0xDCE2EA, dark: 0x263442)
    static let danger        = Color.dsAdaptive(light: 0xD64545, dark: 0xFF7A7A)

    // History — HISTORY_SPEC.md §3 names four roles the handoff's own palette has
    // no word for. They are here rather than beside the history views because
    // they are semantic (a track, an axis, an over-budget fill), not one screen's
    // private colours the way `DS.scanSurface` is.
    //
    /// The calorie bar of a day that went **over** its target. §0.3: over budget
    /// is neutral grey — never red, never orange, never a warning icon.
    static let overBudget = Color.dsAdaptive(light: 0xB4C0CB, dark: 0x566878)
    /// The 1.5pt target mark on that bar. Spec gives no dark value; this one is
    /// derived to stay visible on `trackBg` while losing to the fill beside it.
    static let axis       = Color.dsAdaptive(light: 0xC0CAD4, dark: 0x6E7F90)
    /// The unfilled part of a progress bar. Distinct from `neutral150` on
    /// purpose: §3 gives it its own value (#E9EEF2 vs #E9EDF2), and a track is a
    /// different job from a divider even where the two happen to look alike.
    static let trackBg    = Color.dsAdaptive(light: 0xE9EEF2, dark: 0x223040)
    /// The blue tint behind an active filter chip and behind the monogram of a
    /// meal with no photo. Its dark value is `blue100`'s — same role, same tint.
    static let chipOnBg   = Color.dsAdaptive(light: 0xE7EFF6, dark: 0x143A58)

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
