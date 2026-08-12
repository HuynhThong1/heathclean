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

    /// The sheet is sized to what is in it, measured below.
    ///
    /// A fixed detent cannot work here: the two call sites' messages differ in
    /// length, and Dynamic Type or a long dish name wraps them further. The 280pt
    /// this used to be left an empty band under "Huỷ" on the short message and
    /// would have run out of room on the tall one.
    @State private var contentHeight: CGFloat = 280

    /// Clearance under the last button. The sheet reaches the bottom edge of the
    /// screen and does **not** inset its content, so this is the only thing
    /// keeping "Huỷ" clear of the home indicator — measured at 22pt here, and 0 on
    /// a phone with a home button, which is why it takes the larger of the two.
    ///
    /// It used to be a flat 28pt, which stacked on top of the indicator's 22 and
    /// left ~50pt of empty sheet under the button while the rest of the stack ran
    /// on a 16pt rhythm.
    @State private var bottomClearance: CGFloat = DS.s4

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
        .padding(.bottom, bottomClearance)
        .frame(maxWidth: .infinity)
        // Without this the sheet stretches the stack to the detent's full height,
        // so the measurement below reads back the height it just set and the
        // sheet never shrinks. `vertical: true` pins the stack to its ideal
        // height; the width stays flexible.
        .fixedSize(horizontal: false, vertical: true)
        // Measured in a *background*, not an overlay: `Color.clear` takes hits in
        // SwiftUI, so an overlay would eat the two buttons' taps.
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        bottomClearance = max(DS.s4, proxy.safeAreaInsets.bottom)
                        contentHeight = proxy.size.height
                    }
                    .onChange(of: proxy.size.height) { _, height in
                        contentHeight = height
                    }
            }
        }
        // `presentationBackground`, not `.background` on the stack: a background
        // on the content paints only the content, and anything left over shows
        // the sheet's own backing, which is near-black in dark mode. Colouring
        // the sheet leaves nothing to show through — still worth doing now the
        // height fits, because the corner radius rounds into it.
        .presentationBackground(DS.surfaceCard)
        .presentationDetents([.height(contentHeight)])
        .presentationCornerRadius(DS.rSheet)
    }
}
