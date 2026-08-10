import SwiftUI

/// Typography roles from the handoff README §9.
///
/// The spec quotes CSS weights (650, 750, 800). Be Vietnam Pro ships discrete
/// faces, so they map to the nearest cut: 800 → ExtraBold, 750/700 → Bold,
/// 650/600 → SemiBold, 500 → Medium, 400 → Regular.
///
/// Tracking is quoted in `em` and converted here to points, since SwiftUI's
/// `.tracking()` is absolute.
struct HFTextStyle {
    let font: Font
    let tracking: CGFloat

    init(size: CGFloat, face: String, trackingEm: CGFloat = 0, relativeTo: Font.TextStyle = .body) {
        self.font = Font.custom(face, size: size, relativeTo: relativeTo)
        self.tracking = size * trackingEm
    }
}

extension View {
    func hfStyle(_ style: HFTextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}

extension Text {
    /// Keeps the result a `Text` so styled runs can still be concatenated with
    /// `+`, which the `View` overload above would erase.
    func hfStyle(_ style: HFTextStyle) -> Text {
        font(style.font).tracking(style.tracking)
    }
}

enum HFType {
    private static let extraBold = DSFontName.extrabold
    private static let bold = DSFontName.bold
    private static let semibold = DSFontName.semibold
    private static let medium = DSFontName.medium
    private static let regular = DSFontName.regular

    /// 52 / 800 / −0.04em — the ring centre.
    static let heroMetric = HFTextStyle(
        size: 52, face: extraBold, trackingEm: -0.04, relativeTo: .largeTitle
    )
    /// 38–46 / 800 / −0.03em.
    static let bigMetric = HFTextStyle(
        size: 38, face: extraBold, trackingEm: -0.03, relativeTo: .largeTitle
    )
    /// 27–29 / 800 / −0.025em — screen titles.
    static let screenTitle = HFTextStyle(
        size: 29, face: extraBold, trackingEm: -0.025, relativeTo: .title
    )
    /// 20–22 / 800 / −0.02em.
    static let cardMetric = HFTextStyle(
        size: 21, face: extraBold, trackingEm: -0.02, relativeTo: .title3
    )
    /// 17 / 750 — the hero's three stat values.
    static let statValue = HFTextStyle(size: 17, face: bold, relativeTo: .body)
    /// 15 / 750.
    static let sectionHead = HFTextStyle(size: 15, face: bold, relativeTo: .subheadline)
    /// 14.5 / 650 — the Vietnamese half of a label pair.
    static let rowLabel = HFTextStyle(size: 14.5, face: semibold, relativeTo: .subheadline)
    /// 14 / 700 — row values such as meal kcal.
    static let rowValue = HFTextStyle(size: 14, face: bold, relativeTo: .subheadline)
    /// 13.5–15 / 400–500.
    static let body = HFTextStyle(size: 14, face: regular, relativeTo: .body)
    static let bodyMedium = HFTextStyle(size: 14, face: medium, relativeTo: .body)
    /// 13 / 650.
    static let caption = HFTextStyle(size: 13, face: semibold, relativeTo: .footnote)
    /// 11.5 — the English half of a label pair, and small meta.
    static let subLabel = HFTextStyle(size: 11.5, face: regular, relativeTo: .caption)
    static let subLabelSemibold = HFTextStyle(size: 11.5, face: semibold, relativeTo: .caption)
    /// 11 / 700 / +0.16em.
    static let eyebrow = HFTextStyle(
        size: 11, face: bold, trackingEm: 0.16, relativeTo: .caption2
    )
}
