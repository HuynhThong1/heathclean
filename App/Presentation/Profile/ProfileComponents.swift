import SwiftUI

/// The three primitives PROFILE_SPEC §1 measures, plus the type steps it names.
///
/// They are here rather than in `DesignSystem/` because the spec measures them
/// for this screen: a **borderless** card (`HFCard` carries §9's two shadows,
/// and §1's table says "không shadow"), a row whose value sits on the trailing
/// edge, and a section label with its own tracking. Nothing outside Profile and
/// Sửa hồ sơ draws them.

// MARK: - Type

/// PROFILE_SPEC §1's measurement table, as type steps.
///
/// Only the sizes the handoff's own scale has no answer for. Everything that
/// matches — the 14.5/650 row label, the 11.5/400 sub-line — keeps using
/// `HFType`, so a change to the shared scale still reaches this screen.
enum ProfileType {
    /// 11 / 700 / **0.11em** — the section label. `HFType.eyebrow` is the same
    /// size and weight at 0.16em, which is the tab-root eyebrow's tracking, not
    /// this one's.
    static let sectionLabel = HFTextStyle(
        size: 11, face: DSFontName.bold, trackingEm: 0.11, relativeTo: .caption2
    )
    /// 12.5 / 500 — a settings row's trailing value.
    static let rowValue = HFTextStyle(size: 12.5, face: DSFontName.medium, relativeTo: .footnote)
    /// 15 / 650 — the same slot in the edit form, where the value is the point
    /// of the row rather than a status.
    static let rowValueStrong = HFTextStyle(
        size: 15, face: DSFontName.semibold, relativeTo: .subheadline
    )
    /// 11.5 / 600 — the "Trong ngày" / "Cuối ngày" group headings.
    static let groupHeading = HFTextStyle(
        size: 11.5, face: DSFontName.semibold, relativeTo: .caption
    )
    /// 19 / 700 — a header-card figure.
    static let headerStat = HFTextStyle(size: 19, face: DSFontName.bold, relativeTo: .title3)
    /// 11 / 600 — its label.
    static let headerStatLabel = HFTextStyle(
        size: 11, face: DSFontName.semibold, relativeTo: .caption2
    )
    /// 18 / 700 — "Hồ sơ của bạn".
    static let headerName = HFTextStyle(size: 18, face: DSFontName.bold, relativeTo: .title3)
    /// 13 / 600 — the "Sửa" action and the privacy lines' weightier siblings.
    static let inlineAction = HFTextStyle(
        size: 13, face: DSFontName.semibold, relativeTo: .footnote
    )
    /// 13 / 400 — a privacy line.
    static let privacyLine = HFTextStyle(size: 13, face: DSFontName.regular, relativeTo: .footnote)
    /// 34 / 700, monospaced digits — the new-goal figure (§5).
    static let goalFigure = HFTextStyle(
        size: 34, face: DSFontName.bold, trackingEm: -0.02, relativeTo: .largeTitle
    )
    /// 11 / 600 / 0.09em — its eyebrow. A third tracking, and the spec's, which
    /// is why it is not `sectionLabel`.
    static let goalEyebrow = HFTextStyle(
        size: 11, face: DSFontName.semibold, trackingEm: 0.09, relativeTo: .caption2
    )
}

extension DS {
    /// The 8×14 chevron of §1's table, #C0CAD4. `DS.axis` carries exactly that
    /// value in light and a matching quiet grey in dark; naming it here says
    /// which of the two jobs the colour is doing.
    static var chevron: Color { DS.axis }
}

// MARK: - Section label

/// 11pt / 700 / 0.11em on `textMuted`, with §1's 22 / 4 / 10 padding baked in.
///
/// The padding belongs to the label rather than to the stack around it because
/// it is asymmetric — 22 above, 10 below — which a `VStack` spacing cannot
/// express. Every screen that uses these runs its stack at `spacing: 0`.
///
/// **`textMuted`, not the #94A3B2 the reference page draws.** Same call as
/// HISTORY_SPEC §7: a small grey has to carry its contrast on `pageBg`, and
/// #94A3B2 is ~3.2:1 there against `textMuted`'s 5.6:1.
struct SectionLabel: View {
    private let text: Text

    init(_ title: LocalizedStringKey) {
        self.text = Text(title)
    }

    /// For a heading chosen by a `switch` where there is no literal to extract.
    init(verbatim title: String) {
        self.text = Text(verbatim: title)
    }

    var body: some View {
        text
            .hfStyle(ProfileType.sectionLabel)
            .foregroundStyle(DS.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 22)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The quieter heading *inside* a section — "Trong ngày", "Cuối ngày" (§3).
struct SectionSubheading: View {
    private let text: Text

    init(_ title: LocalizedStringKey) {
        self.text = Text(title)
    }

    var body: some View {
        text
            .hfStyle(ProfileType.groupHeading)
            .foregroundStyle(DS.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Card

/// Corner 16, 1pt border, **no shadow** (§1's table).
///
/// This is the whole of the difference from `HFCard`, and it is deliberate:
/// §1's cards butt up against each other down a long settings screen, where two
/// stacked shadows read as a seam rather than as lift.
struct SettingsCard<Content: View>: View {
    var padding: CGFloat = 0
    @ViewBuilder var content: Content

    init(padding: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.rCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.rCard, style: .continuous)
                    .strokeBorder(DS.borderSubtle, lineWidth: 1)
            }
    }
}

/// The 1pt rule §1 puts **between** rows and never above the first.
///
/// The caller places it, rather than each row drawing its own top edge and the
/// first suppressing it: a row does not know its index, and passing one in is a
/// bookkeeping job that goes wrong the first time a row is inserted. Written
/// out, "no divider before the first row" is simply what the code looks like.
///
/// It is full-bleed. The design insets nothing, and an inset rule under a row
/// whose label can wrap to two lines at accessibility sizes stops lining up
/// with anything.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.borderSubtle)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - Row

/// §1's settings row: 13 / 16 padding, 44pt minimum, label left, value and
/// chevron right.
///
/// `caption` is `HFLabel`'s rule restated — a genuine second fact, never the
/// English coming back. "Cân nặng · Đồng bộ từ Apple Health" qualifies; a
/// translation of the line above it does not. See `HFLabel`.
///
/// **The label and the value stack vertically from `.accessibility1`.** §6's
/// last item asks for it, and it is not cosmetic: at `.accessibility3` a
/// two-line label beside a value leaves each about 90pt of width and both wrap
/// to four lines.
struct SettingsRow<Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: Text
    private let caption: Text?
    private let showsChevron: Bool
    private let identifier: String?
    private let action: (() -> Void)?
    private let hasInteractiveTrailing: Bool
    private let trailing: Trailing

    init(
        _ title: LocalizedStringKey,
        caption: LocalizedStringKey? = nil,
        showsChevron: Bool = false,
        identifier: String? = nil,
        hasInteractiveTrailing: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = Text(title)
        self.caption = caption.map { Text($0) }
        self.showsChevron = showsChevron
        self.identifier = identifier
        self.hasInteractiveTrailing = hasInteractiveTrailing
        self.action = action
        self.trailing = trailing()
    }

    /// For a title resolved where it was built — an enum's `label`.
    init(
        verbatim title: String,
        caption: String? = nil,
        showsChevron: Bool = false,
        identifier: String? = nil,
        hasInteractiveTrailing: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = Text(verbatim: title)
        self.caption = caption.map { Text(verbatim: $0) }
        self.showsChevron = showsChevron
        self.identifier = identifier
        self.hasInteractiveTrailing = hasInteractiveTrailing
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        if hasInteractiveTrailing {
            // **A row whose trailing side is a control must not merge.**
            // `.combine` plus `.isStaticText` is right for a label and a value
            // — it stops VoiceOver reading every row twice — and it would
            // swallow a text field whole, leaving the only way to edit the
            // number unreachable. The control carries its own label instead.
            content
                .modifier(OptionalIdentifier(identifier: identifier))
        } else if let action {
            // The frame, the padding and the hit shape are **inside** the label.
            // Outside a `Button` they dress a box the button does not own, and
            // the row would answer only where its glyphs are drawn — the rule
            // CLAUDE.md keeps this codebase relearning.
            Button(action: action) { content.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .modifier(OptionalIdentifier(identifier: identifier))
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
                .modifier(OptionalIdentifier(identifier: identifier))
        }
    }

    private var content: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.s2) {
                    label
                    HStack(spacing: DS.s2) {
                        trailing
                        Spacer(minLength: 0)
                        chevron
                    }
                }
            } else {
                HStack(spacing: DS.s3) {
                    label
                    Spacer(minLength: DS.s2)
                    trailing
                    chevron
                }
            }
        }
        .padding(.horizontal, DS.s4)
        .padding(.vertical, 13)
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 1) {
            title
                .hfStyle(HFType.rowLabel)
                .foregroundStyle(DS.textStrong)
            if let caption {
                caption
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textMuted)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
    }

    @ViewBuilder
    private var chevron: some View {
        if showsChevron {
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.chevron)
                .accessibilityHidden(true)
        }
    }
}

extension SettingsRow where Trailing == RowValue {
    /// The common case: a row whose trailing side is one piece of text.
    init(
        _ title: LocalizedStringKey,
        caption: LocalizedStringKey? = nil,
        value: String?,
        prominent: Bool = false,
        showsChevron: Bool = false,
        identifier: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title,
            caption: caption,
            showsChevron: showsChevron,
            identifier: identifier,
            action: action
        ) {
            RowValue(text: value, prominent: prominent)
        }
    }
}

/// Applies an identifier only when there is one. Setting `""` is not the same
/// as setting nothing — it makes the row queryable by the empty string, which
/// then matches every other element that did the same.
private struct OptionalIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

/// A settings row's trailing text: 12.5/500 `textMuted`, or 15/650 `textStrong`
/// in the edit form where the value is what the row is *for* (§1's table gives
/// both).
struct RowValue: View {
    let text: String?
    var prominent = false

    var body: some View {
        if let text {
            Text(verbatim: text)
                .hfStyle(prominent ? ProfileType.rowValueStrong : ProfileType.rowValue)
                .foregroundStyle(prominent ? DS.textStrong : DS.textMuted)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Previews

#Preview("Primitives · light") {
    ProfileComponentGallery()
        .preferredColorScheme(.light)
}

#Preview("Primitives · dark") {
    ProfileComponentGallery()
        .preferredColorScheme(.dark)
}

#Preview("Primitives · accessibility3") {
    ProfileComponentGallery()
        .environment(\.dynamicTypeSize, .accessibility3)
}

private struct ProfileComponentGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionLabel("THIẾT LẬP")
                SettingsCard {
                    SettingsRow(
                        "Thông tin cơ thể & mục tiêu",
                        value: nil,
                        showsChevron: true,
                        action: {}
                    )
                    SettingsDivider()
                    SettingsRow(
                        "Apple Health",
                        value: "Chưa kết nối",
                        showsChevron: true,
                        action: {}
                    )
                    SettingsDivider()
                    SettingsRow("Đơn vị đo", value: "kg · cm · kcal")
                }

                SectionLabel("CƠ THỂ")
                SettingsCard {
                    SettingsRow(
                        "Cân nặng hiện tại",
                        caption: "Cập nhật khi bạn muốn — không có nhắc nhở cân hằng ngày.",
                        value: "98,0 kg",
                        prominent: true
                    )
                }
            }
            .padding(.horizontal, DS.s4)
        }
        .background(DS.surfacePage)
    }
}
