import SwiftUI

/// The dashboard hero ring (handoff §6.4).
///
/// Three stacked circles, stroke 17, rotated −90° so progress starts at the top:
/// 1. track — `neutral150`
/// 2. progress — brand blue, round cap, `min(fraction, 1)`
/// 3. overflow — drawn only past 100%, `min(fraction − 1, 1)`
///
/// The overflow arc is the entire over-budget signal, and it is `DS.danger`
/// rather than §6.4's `neutral400` **at the product owner's request**. Worth
/// knowing what that trades away: §4 and `plan.md` §18 chose grey deliberately —
/// the app states a fact and never scolds — and red is the one colour a casual
/// user reads as "you did something wrong". The copy stays neutral, so the note
/// under the ring still says what happened rather than what to do about it; only
/// the arc changed. Reverting means this line and the history and Insights bars,
/// which follow it.
struct CalorieRing: View {
    let fraction: Double
    let side: CGFloat = 214
    private let lineWidth: CGFloat = 17

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.neutral150, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(fraction, 1))
                .stroke(DS.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            if fraction > 1 {
                Circle()
                    .trim(from: 0, to: min(fraction - 1, 1))
                    .stroke(
                        DS.danger,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
            }
        }
        .rotationEffect(.degrees(-90))
        .frame(width: side, height: side)
        .animation(DS.ease, value: fraction)
        .accessibilityHidden(true) // the centre text carries the meaning
    }
}
