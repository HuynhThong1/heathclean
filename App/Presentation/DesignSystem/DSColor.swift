import SwiftUI

/// Semantic colour aliases, ported from the FPT IS design system
/// (`tokens/semantic.css`). Application code should reference these, not the
/// raw ramps in `DSPalette`.
///
/// **Dark values are derived, not brand-supplied.** The source design system
/// defines a light palette only. The dark side of each pair below was chosen
/// here to preserve the same intent and contrast relationships:
///
/// - Surfaces descend to near-black blue-greys rather than inverting the light
///   ramp, so cards stay lighter than the page as they do in light mode.
/// - Text uses the light neutral ramp read upside down (`neutral-900` → `100`).
/// - Brand colours shift one step lighter for legibility on dark surfaces:
///   fills use `blue-500`, and brand *text* uses the 300–400 range, because
///   `#0062B0` on a dark surface falls below a comfortable contrast ratio.
///
/// Replace these with real values if the brand team publishes a dark palette.
enum DSColor {
    // MARK: Text

    static let textStrong = Color.dsAdaptive(light: 0x0F1B27, dark: 0xF2F5F8)
    static let textBody = Color.dsAdaptive(light: 0x1F2E3D, dark: 0xDDE4EA)
    static let textMuted = Color.dsAdaptive(light: 0x506173, dark: 0x94A3B2)
    static let textSubtle = Color.dsAdaptive(light: 0x6E7F90, dark: 0x6E7F90)
    static let textOnBrand = Color.dsFixed(0xFFFFFF)
    static let textLink = Color.dsAdaptive(light: 0x0062B0, dark: 0x4D9BDB)

    // MARK: Surfaces

    static let surfacePage = Color.dsAdaptive(light: 0xF8FAFC, dark: 0x0B1219)
    static let surfaceCard = Color.dsAdaptive(light: 0xFFFFFF, dark: 0x131E29)
    static let surfaceSunken = Color.dsAdaptive(light: 0xF2F5F8, dark: 0x0E1720)
    static let surfaceBrand = Color.dsAdaptive(light: 0x0062B0, dark: 0x1A7CCB)
    static let surfaceBrandStrong = Color.dsAdaptive(light: 0x003F71, dark: 0x004E8C)

    // MARK: Brand action

    static let actionPrimary = Color.dsAdaptive(light: 0x0062B0, dark: 0x1A7CCB)
    static let actionPrimaryPressed = Color.dsAdaptive(light: 0x003F71, dark: 0x0062B0)
    static let actionAccent = Color.dsAdaptive(light: 0xF37021, dark: 0xF37021)
    static let actionAccentPressed = Color.dsAdaptive(light: 0xC4520E, dark: 0xE0611A)

    /// Brand blue as *text or icon* rather than a fill.
    static let brandOnSurface = Color.dsAdaptive(light: 0x0062B0, dark: 0x86BEEA)

    // MARK: Borders

    static let borderSubtle = Color.dsAdaptive(light: 0xDDE4EA, dark: 0x23303D)
    static let borderDefault = Color.dsAdaptive(light: 0xC0CAD4, dark: 0x33424F)
    static let borderStrong = Color.dsAdaptive(light: 0x94A3B2, dark: 0x4A5A69)
    static let borderBrand = Color.dsAdaptive(light: 0x0062B0, dark: 0x4D9BDB)

    // MARK: Status

    static let success = Color.dsAdaptive(light: 0x0E9640, dark: 0x47C674)
    static let warning = Color.dsAdaptive(light: 0xE8A317, dark: 0xE8A317)
    static let danger = Color.dsAdaptive(light: 0xD5342B, dark: 0xE8635B)
}
