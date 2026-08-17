import SwiftUI

extension DS {
    /// The raised pill of §1's segmented control. White in light, and #22303D in
    /// dark — which is `neutral900`'s dark value and for the same reason: on a
    /// #131E29 card a pill has to *lift*, and every surface token below the card
    /// recedes instead. It lives here rather than in `DesignTokens.swift`
    /// because one control uses it, the way `DS.scanSurface` lives with the
    /// camera.
    static let segmentedPill = Color.dsAdaptive(light: 0xFFFFFF, dark: 0x22303D)
}

/// §1's segmented control: track 46 tall (38pt pill + 4pt inset), corner 12 on
/// the track and 9 on the pill, pill raised by one soft shadow.
///
/// Hand-built rather than `Picker(.segmented)`, for two reasons the spec forces:
/// the pill carries an icon beside its label (§2's sun and moon), and the whole
/// control has a **disabled** state that still has to show where the marker
/// sits — a disabled `Picker` dims but also stops reporting a useful
/// accessibility value, and §2 asks it to read "đang theo hệ thống" instead.
///
/// The 650 / 600 weight split the reference page draws is not reproduced: Be
/// Vietnam Pro ships discrete cuts and both round to SemiBold, so the selected
/// state is carried by the pill and the text colour, which is what actually
/// distinguishes them on screen.
///
/// **Only the segments carry identifiers, never the track.** An
/// `accessibilityIdentifier` on a container propagates down the subtree, and a
/// caller labelling the whole control took the segments' own identifiers with
/// it — leaving a row of buttons no test could name. Ask for
/// `profile.language.en`, not `profile.language`.
struct SegmentedTrack<Value: Hashable>: View {
    struct Option {
        let value: Value
        let label: Text
        /// SF Symbol drawn before the label, if the design puts one there.
        var symbol: String?
        let identifier: String
        /// What VoiceOver announces. The label is a `Text` and cannot be read
        /// back out of one.
        let accessibilityLabel: String
    }

    @Binding var selection: Value
    let options: [Option]
    var isEnabled = true
    /// Appended to each segment's accessibility value when the control is off —
    /// "đang theo hệ thống" (§2). Without it a dimmed control with a marker
    /// still on "Sáng" is indistinguishable from a working one.
    var disabledNote: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var pill

    var body: some View {
        layout {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                segment(option)
            }
        }
        .padding(4)
        .background(DS.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(isEnabled ? 1 : 0.5)
        .disabled(!isEnabled)
    }

    /// Side by side, until the text is large enough that three segments cannot
    /// share a phone's width. "Tiếng Việt" at `.accessibility3` in a third of
    /// 358pt shrinks past legibility however hard `minimumScaleFactor` is
    /// pushed; stacked, each option gets the full width and stays readable.
    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = selection == option.value

        return Button {
            guard selection != option.value else { return }
            if reduceMotion {
                selection = option.value
            } else {
                withAnimation(DS.ease) { selection = option.value }
            }
        } label: {
            HStack(spacing: 7) {
                if let symbol = option.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                }
                option.label
                    .hfStyle(HFType.rowLabel)
            }
            .foregroundStyle(isSelected ? DS.textStrong : DS.textMuted)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.s2)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 38)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(DS.segmentedPill)
                        .shadow(color: Color(hex: 0x0F1B27).opacity(0.10), radius: 3, y: 1)
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            // Without this the segment answers only where its glyphs are drawn
            // and the padding around them is dead — the rule this codebase keeps
            // relearning, recorded in CLAUDE.md.
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(option.identifier)
        .accessibilityLabel(Text(verbatim: option.accessibilityLabel))
        .accessibilityValue(Text(verbatim: accessibilityValue(isSelected: isSelected)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func accessibilityValue(isSelected: Bool) -> String {
        let state = isSelected ? L("đang chọn") : L("chưa chọn")
        guard !isEnabled, let disabledNote else { return state }
        return "\(state), \(disabledNote)"
    }
}
