import SwiftUI

/// Shared chrome for every screen: brand page surface behind a `List`/`Form`,
/// brand-tinted controls, and the brand typeface on navigation titles.
///
/// SwiftUI's grouped list paints its own system background, so it has to be
/// hidden before the design system's page colour shows through.
struct DSScreenChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(DSColor.surfacePage)
            .tint(DSColor.actionPrimary)
    }
}

extension View {
    func dsScreen() -> some View {
        modifier(DSScreenChrome())
    }

    /// A list row on the card surface, with the design system's own separator.
    func dsRow() -> some View {
        listRowBackground(DSColor.surfaceCard)
            .listRowSeparatorTint(DSColor.borderSubtle)
    }
}

/// Section headers use the overline step — small, semibold, wide-tracked.
struct DSSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(DSType.overline)
            .kerning(1.44) // --tracking-overline, 0.12em at 12pt
            .foregroundStyle(DSColor.textMuted)
    }
}
