import SwiftUI

/// Vietnamese label with its English sub-label beneath — the pattern that
/// repeats on every screen (handoff §4).
///
/// Read as a single element by VoiceOver, Vietnamese first: the two halves name
/// the same thing, and announcing them separately would double every row.
struct LabelPair: View {
    let vi: String
    let en: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(vi)
                .hfStyle(HFType.rowLabel)
                .foregroundStyle(DS.textStrong)
            Text(en)
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textSubtle)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vi), \(en)")
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Section heading, which sits *outside* the card (handoff §4).
struct HFSectionHeader: View {
    let vi: String
    let en: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.s2) {
            Text(vi)
                .hfStyle(HFType.sectionHead)
                .foregroundStyle(DS.textStrong)
            Text(en)
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textSubtle)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vi), \(en)")
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
/// screen this replaced happened to pass the same sentence through
/// `String(localized:)`; deleting that screen took the key with it, which is how
/// the whole set came to light.
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
