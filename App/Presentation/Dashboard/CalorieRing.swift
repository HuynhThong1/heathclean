import SwiftUI

/// The dashboard hero ring (handoff §6.4).
///
/// Three stacked circles, stroke 17, rotated −90° so progress starts at the top:
/// 1. track — `neutral150`
/// 2. progress — brand blue, round cap, `min(fraction, 1)`
/// 3. overflow — `neutral400`, drawn only past 100%, `min(fraction − 1, 1)`
///
/// The overflow arc is the entire over-budget signal. It is grey on purpose:
/// §4 rules out red, and rules out anything that reads as a reprimand.
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
                        DS.neutral400,
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
