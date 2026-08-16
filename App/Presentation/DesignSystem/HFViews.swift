import SwiftUI

/// The row label that repeats on every screen (handoff §4).
///
/// **This was `LabelPair`, and it drew two lines**: Vietnamese, with the English
/// underneath. §4 asks for that because the design has no way to choose a
/// language — but `AppLanguage` is that way, and once it exists a second line
/// shows the user a language they did not ask for. One line, in the language
/// they picked.
///
/// `caption` is **not** the old English line coming back. It is for a genuine
/// second fact — "Dùng cho công thức Mifflin-St Jeor" under "Giới tính sinh học"
/// — which was living in the `en:` slot because that was the only slot there
/// was, and would have been thrown away with the translations.
struct HFLabel: View {
    private let text: Text
    private let captionText: Text?
    private let alignment: HorizontalAlignment

    init(
        _ title: LocalizedStringKey,
        caption: LocalizedStringKey? = nil,
        alignment: HorizontalAlignment = .leading
    ) {
        self.text = Text(title)
        self.captionText = caption.map { (key: LocalizedStringKey) in Text(key) }
        self.alignment = alignment
    }

    /// For copy that was already resolved where it was built — an enum's
    /// `label`, a model's sentence. A single `String` initializer would take
    /// every literal written into it out of the catalog, which is the mistake
    /// `GrayNote` made; this one is named so the call site says which it is.
    init(verbatim title: String, caption: String? = nil, alignment: HorizontalAlignment = .leading) {
        self.text = Text(verbatim: title)
        self.captionText = caption.map { Text(verbatim: $0) }
        self.alignment = alignment
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            text
                .hfStyle(HFType.rowLabel)
                .foregroundStyle(DS.textStrong)
            if let captionText {
                captionText
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
            }
        }
        // Still one element even with a caption: the two lines describe one
        // thing, and announcing them separately doubles every row.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Section heading, which sits *outside* the card (handoff §4).
struct HFSectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
            Text(title)
                .hfStyle(HFType.sectionHead)
                .foregroundStyle(DS.textStrong)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// White card on the cool page background: 1px subtle border, soft shadow.
struct HFCard<Content: View>: View {
    var padding: CGFloat = DS.s5
    var radius: CGFloat = DS.rCard
    /// Draws the 4px brand bar across the top edge.
    var accent: Color?
    @ViewBuilder var content: Content

    init(
        padding: CGFloat = DS.s5,
        radius: CGFloat = DS.rCard,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surfaceCard)
            .overlay(alignment: .top) {
                if let accent {
                    Rectangle().fill(accent).frame(height: 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(DS.borderSubtle, lineWidth: 1)
            }
            // shadow-sm from §9
            .shadow(color: Color(hex: 0x0F1B27).opacity(0.06), radius: 1, y: 1)
            .shadow(color: Color(hex: 0x0F1B27).opacity(0.04), radius: 4, y: 2)
    }
}

/// Neutral note pill. Used for the budget status line and the explanatory
/// asides — grey by design, never alarming (handoff §4).
///
/// **It takes a `LocalizedStringKey`, not a `String`, and that is the point.** It
/// used to take a `String`, so every literal written into one was a plain Swift
/// literal that `xcstringstool` never saw: six pieces of copy — the Apple Health
/// privacy line, the scan explainer, two onboarding asides, two Insights empty
/// states — sat outside `Localizable.xcstrings` with nothing to show it. The
/// History day panel's empty state was in the catalog only by accident, because the
/// screen this replaced happened to pass the same sentence through the resolving
/// call (`String(localized:)` then, `L()` now); deleting that screen took the key
/// with it, which is how the whole set came to light.
///
/// A message that was already localized where it was built — a status line, an
/// error — comes in through `init(verbatim:)` instead, so it is not looked up a
/// second time with itself as the key.
struct GrayNote: View {
    private let text: Text

    init(text: LocalizedStringKey) {
        self.text = Text(text)
    }

    init(verbatim text: String) {
        self.text = Text(verbatim: text)
    }

    var body: some View {
        text
            .hfStyle(HFType.body)
            .foregroundStyle(DS.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.s3)
            .padding(.vertical, DS.s3)
            .background(DS.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
