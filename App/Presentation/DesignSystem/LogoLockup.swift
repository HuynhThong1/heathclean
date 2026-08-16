import SwiftUI

/// The wordmark on its own — the lockups below and the splash all draw it.
///
/// §1: Be Vietnam Pro **Bold (700)**, never 800, cased `HealthClean`, and never
/// orange.
struct BrandWordmark: View {
    let fontSize: CGFloat
    var tone: BrandTone = .light

    var body: some View {
        Text(verbatim: "HealthClean")
            .font(.custom(DSFontName.bold, size: fontSize))
            .tracking(Self.tracking(forFontSize: fontSize))
            .foregroundStyle(tone.wordmark)
    }

    /// §1's three tracking steps. Below 14pt the negative tracking closes the
    /// counters, so it stops rather than scaling down for ever.
    static func tracking(forFontSize size: CGFloat) -> CGFloat {
        switch size {
        case 20...: -0.025 * size
        case 14...: -0.02 * size
        default: 0
        }
    }
}

/// BRAND_SPEC §1's lockups — mark plus wordmark, proportioned entirely against
/// the mark height `h`, so one definition holds at every size.
///
/// The 0.5h of clear space is **inside** this view. It is a minimum the spec
/// states and a component that can be crowded does not keep it; callers that want
/// the glyphs tight against something else should draw `BrandMark` and
/// `BrandWordmark` themselves, which is what the splash does.
///
/// **"Cao chữ" is read as the font size**, not as cap height. It is the number a
/// caller can set directly; if the intent was cap height, the two multipliers
/// below are the only change (0.5h and 0.42h become roughly 0.71h and 0.6h).
///
/// §1's "lockup ngang dưới 96pt rộng → chỉ dùng mark" is a usage rule and is not
/// enforced here: nothing in the app draws a lockup yet, so a fallback would be a
/// layout path with no call site to verify it against. Below that width, draw
/// `BrandMark` instead.
struct LogoLockup: View {
    enum Orientation { case horizontal, vertical }

    let orientation: Orientation
    var tone: BrandTone = .light
    var markHeight: CGFloat = 40

    private var gap: CGFloat { 0.32 * markHeight }
    private var clearSpace: CGFloat { 0.5 * markHeight }
    private var fontSize: CGFloat {
        (orientation == .horizontal ? 0.5 : 0.42) * markHeight
    }

    var body: some View {
        Group {
            switch orientation {
            case .horizontal:
                HStack(spacing: gap) {
                    BrandMark(side: markHeight, tone: tone)
                    BrandWordmark(fontSize: fontSize, tone: tone)
                }
            case .vertical:
                VStack(spacing: gap) {
                    BrandMark(side: markHeight, tone: tone)
                    BrandWordmark(fontSize: fontSize, tone: tone)
                }
            }
        }
        .padding(clearSpace)
        // One element, one name. The mark and the word are one logo to a screen
        // reader, and neither half says anything on its own.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "HealthClean"))
    }
}

// MARK: - Previews

#Preview("Lockup · ngang") {
    VStack(spacing: 0) {
        LogoLockup(orientation: .horizontal, tone: .light, markHeight: 56)
            .frame(maxWidth: .infinity)
            .background(DS.surfacePage)
        LogoLockup(orientation: .horizontal, tone: .dark, markHeight: 56)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0x0B1219))
        LogoLockup(orientation: .horizontal, tone: .onBrand, markHeight: 56)
            .frame(maxWidth: .infinity)
            .background(DS.blue)
        LogoLockup(orientation: .horizontal, tone: .mono, markHeight: 56)
            .frame(maxWidth: .infinity)
            .background(DS.surfacePage)
    }
}

#Preview("Lockup · dọc") {
    HStack(spacing: 0) {
        LogoLockup(orientation: .vertical, tone: .light, markHeight: 72)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.surfacePage)
        LogoLockup(orientation: .vertical, tone: .onBrand, markHeight: 72)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.blue)
    }
}

/// The three tracking steps, at the sizes either side of each boundary.
#Preview("Wordmark · tracking") {
    VStack(alignment: .leading, spacing: 14) {
        ForEach([12.0, 14.0, 19.0, 20.0, 34.0], id: \.self) { size in
            BrandWordmark(fontSize: size, tone: .light)
        }
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DS.surfacePage)
}
