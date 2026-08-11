import SwiftUI

/// Asks before something irreversible, in the app's own design language.
///
/// `confirmationDialog` was here before and it is the native pattern, but it is
/// also plain system UI: system face, system greys, system spacing, dropped into
/// a screen that is otherwise entirely `DS.*` and Be Vietnam Pro. On a dark
/// surface the mismatch is loud, and it is the one moment the app asks the user
/// to be careful — the worst moment to look like a different app.
///
/// Presented as a sheet with a content-sized detent, so it behaves the way a
/// mobile confirmation should: comes from the bottom, dismissible by swipe, thumb
/// can reach both buttons.
///
/// The destructive action is a **filled red button** and Cancel is a plain text
/// action beneath it. An earlier version had this the other way round — Cancel
/// filled, delete quiet — on the argument that the irreversible action should not
/// sit under a resting thumb. The product owner wanted red to carry the weight,
/// which is the more conventional reading: the button that looks like the
/// consequence *is* the consequence.
struct HFDestructiveConfirm: View {
    let title: String
    let message: String
    let confirmLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            Capsule()
                .fill(DS.neutral300)
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)

            Text(title)
                .font(.custom(DSFontName.bold, size: 19))
                .foregroundStyle(DS.textStrong)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .hfStyle(HFType.body)
                .foregroundStyle(DS.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            // Everything is styled *inside* the label. Outside it, the modifiers
            // dress a box the Button does not own: the tap area stays where the
            // glyphs are drawn, so the button only answered on the text itself —
            // the same mistake this file was meant to fix elsewhere.
            Button(action: onConfirm) {
                Text(confirmLabel)
                    .font(.custom(DSFontName.semibold, size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(
                        DS.danger,
                        in: RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("confirm.destructive")

            // Cancel steps back to a plain text action. Filling both would put two
            // shouting buttons side by side and leave neither reading as the
            // consequence — and red carrying the weight is what was asked for.
            Button(action: onCancel) {
                Text("Huỷ")
                    .font(.custom(DSFontName.semibold, size: 16))
                    .foregroundStyle(DS.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("confirm.cancel")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `presentationBackground`, not `.background` on the stack. The detent is
        // a fixed height and the content is shorter than it, so a background on
        // the content only paints the content: the leftover strip showed the
        // sheet's own backing, which is near-black in dark mode. This colours the
        // sheet itself, so there is nothing left to show through.
        .presentationBackground(DS.surfaceCard)
        .presentationDetents([.height(280)])
        .presentationCornerRadius(DS.rSheet)
    }
}
