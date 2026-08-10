import SwiftUI

/// Bundled weights of the brand typeface. The design system substitutes
/// Be Vietnam Pro for the unshipped corporate font — see `tokens/fonts.css`
/// upstream. Swap these names if the licensed font is ever supplied.
enum DSFontName {
    static let light = "BeVietnamPro-Light"
    static let regular = "BeVietnamPro-Regular"
    static let medium = "BeVietnamPro-Medium"
    static let semibold = "BeVietnamPro-SemiBold"
    static let bold = "BeVietnamPro-Bold"
    static let extrabold = "BeVietnamPro-ExtraBold"
}

/// Type scale ported from `tokens/typography.css`.
///
/// Two deliberate departures from the source, both because it was authored for
/// desktop web:
///
/// - The `display-xl` (64pt) and `display-l` (52pt) steps are omitted. Nothing
///   at that size fits a phone; `statValue` is the largest step here.
/// - Every step is declared `relativeTo:` a system text style, so the scale
///   still responds to Dynamic Type. The numbers are the design system's, but
///   they are a starting size rather than a fixed one.
enum DSType {
    static let displayM = Font.custom(DSFontName.extrabold, size: 40, relativeTo: .largeTitle)
    static let h1 = Font.custom(DSFontName.bold, size: 34, relativeTo: .largeTitle)
    static let h2 = Font.custom(DSFontName.bold, size: 28, relativeTo: .title)
    static let h3 = Font.custom(DSFontName.semibold, size: 22, relativeTo: .title2)
    static let h4 = Font.custom(DSFontName.semibold, size: 18, relativeTo: .title3)

    static let bodyLarge = Font.custom(DSFontName.regular, size: 18, relativeTo: .body)
    static let body = Font.custom(DSFontName.regular, size: 16, relativeTo: .body)
    static let bodyMedium = Font.custom(DSFontName.medium, size: 16, relativeTo: .body)
    static let bodySemibold = Font.custom(DSFontName.semibold, size: 16, relativeTo: .body)

    static let bodySmall = Font.custom(DSFontName.regular, size: 14, relativeTo: .subheadline)
    static let bodySmallMedium = Font.custom(DSFontName.medium, size: 14, relativeTo: .subheadline)
    static let bodySmallSemibold = Font.custom(DSFontName.semibold, size: 14, relativeTo: .subheadline)

    static let caption = Font.custom(DSFontName.regular, size: 13, relativeTo: .caption)
    static let captionSemibold = Font.custom(DSFontName.semibold, size: 13, relativeTo: .caption)
    static let overline = Font.custom(DSFontName.semibold, size: 12, relativeTo: .caption2)

    /// The headline number in a `DSStatBlock`.
    static let statValue = Font.custom(DSFontName.extrabold, size: 44, relativeTo: .largeTitle)
    /// Badge text — 12.5pt upstream, rounded to 12.
    static let badge = Font.custom(DSFontName.semibold, size: 12, relativeTo: .caption2)
}
