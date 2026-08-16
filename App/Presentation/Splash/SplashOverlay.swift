import SwiftUI

/// BRAND_SPEC §3 — "Vệt quét", the 860ms opening, drawn **over** an
/// already-mounted root view rather than as a screen in the navigation flow.
///
/// A band of light sweeps down the mark and the dome appears in its wake, which
/// is the app's own gesture: you scan a meal and it resolves. The dome is never
/// drawn progressively — it is complete from the first frame and simply covered,
/// and a rectangle slides off it. That distinction is the whole implementation:
/// a static mask that only moves, no morphing path, no animated mask, no blur,
/// no glow.
///
/// The overlay gates nothing. The dashboard loads underneath the entire time, so
/// this tears off at 860ms whether the data arrived at 200ms or has not arrived
/// at all, and a launch from a notification navigates below it while it counts.
/// There is deliberately no spinner — a splash that can spin is one that can hang.
///
/// **Frame 0 has to be the launch image, to the point**, and that image is not
/// being re-exported: blue, and the white bowl 112pt wide with its centre at 46%
/// of the height. So the bowl is drawn at its final size from the first frame and
/// never animates, and its position is derived from the ratios the launch image
/// was generated from rather than from a number typed twice.
struct SplashOverlay: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far the mask rectangle is pushed up off the dome. At `-markSide` it
    /// covers the dome completely; at 0 the dome is fully out.
    ///
    /// **Frame 0 has to be the default, not something the timeline sets.** SwiftUI
    /// renders once before `.task` runs, so a state that starts open would show
    /// the finished dome for one frame — a flash at precisely the hand-off this
    /// whole file exists to make invisible.
    @State private var revealOffset: CGFloat = -SplashOverlay.markSide
    /// The sweep band's centre, **in grid units measured from the top of the mark's
    /// box** — see `bandOffset(for:)` for why it is expressed that way.
    @State private var bandUnitY: CGFloat = -2
    @State private var bandOpacity: Double = 0
    /// Only Reduce Motion moves this; the full timeline reveals by mask instead
    /// and turns it on straight away. Starting at 0 in **both** modes keeps frame
    /// 0 identical, and costs the full timeline nothing: the mask is covering the
    /// dome at that point anyway.
    @State private var domeOpacity: Double = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 6
    @State private var overlayOpacity: Double = 1

    /// §2: the bowl is 112pt wide on the launch screen.
    private static let bowlWidth: CGFloat = 112
    /// **The mark's box, which is not 112.** The bowl spans only 18 of the grid's
    /// 24 units, so a 112pt box would draw an 84pt bowl and frame 0 would no
    /// longer match the launch image. §3's snippet writes `.frame(112, 112)` on
    /// the box; the prose above it, and §2, say the *bowl* is 112 — and the
    /// launch image measures 112.0pt on screen, so that is the one that holds.
    private static let markSide: CGFloat = bowlWidth / BrandMark.bowlWidthRatio
    private static let unit: CGFloat = markSide / 24
    /// §2 puts the bowl's centre at 46% of the screen height.
    private static let bowlCentreYRatio: CGFloat = 0.46

    /// §3's `VStack(spacing: 20)` cannot be used as written — a stack would make
    /// the mark's position depend on the wordmark's height, and frame 0 would stop
    /// matching the launch image the moment the type metrics changed. The gap is
    /// therefore measured from the **bowl's** bottom edge, which is what the eye
    /// reads as the bottom of the mark; the box carries about 12pt of empty space
    /// below that.
    private static let wordmarkGap: CGFloat = 20
    /// §3 does not size the splash wordmark, only fades and lifts it. Kept at the
    /// vertical lockup's ratio against the bowl width.
    private static var wordmarkSize: CGFloat { 0.42 * bowlWidth }

    var body: some View {
        GeometryReader { proxy in
            let bowlCentreY = proxy.size.height * Self.bowlCentreYRatio
            // The bowl sits below the centre of the mark's box, so the box is
            // lifted by that much for the bowl itself to land on the mark.
            let markCentreY = bowlCentreY - Self.markSide * BrandMark.bowlCentreOffsetRatio
            let bowlBottomY = bowlCentreY + Self.markSide * (9 / 24) / 2

            ZStack {
                DS.blue.ignoresSafeArea()

                mark
                    .frame(width: Self.markSide, height: Self.markSide)
                    .position(x: proxy.size.width / 2, y: markCentreY)

                BrandWordmark(fontSize: Self.wordmarkSize, tone: .onBrand)
                    .opacity(wordmarkOpacity)
                    .position(
                        x: proxy.size.width / 2,
                        y: bowlBottomY + Self.wordmarkGap + Self.wordmarkSize / 2
                    )
                    .offset(y: wordmarkOffset)
            }
            .opacity(overlayOpacity)
        }
        .ignoresSafeArea()
        // Nothing here is worth reading, and it is gone before a sentence would
        // finish. §3: the overlay says nothing for its whole 860ms.
        .accessibilityHidden(true)
        .task {
            if reduceMotion {
                await runReducedTimeline()
            } else {
                await runFullTimeline()
            }
            onFinished()
        }
    }

    /// The three layers in §3's order: the masked dome, the bowl over it, and the
    /// band over both.
    ///
    /// The band is white at 0.42 over a white bowl, so it is invisible while it
    /// crosses the bowl and shows only against the blue and over the dome — which
    /// is the point. It is a flat `Capsule`, never a gradient.
    private var mark: some View {
        ZStack {
            DomeArc()
                .stroke(
                    BrandTone.onBrand.dome,
                    style: StrokeStyle(
                        lineWidth: BrandMark.domeLineWidth(side: Self.markSide),
                        lineCap: .round
                    )
                )
                .opacity(domeOpacity)
                .mask(
                    // Static: one rectangle, and only its offset changes. Its
                    // lower edge is the reveal line, travelling from the top of
                    // the box to the bottom.
                    Rectangle()
                        .frame(height: Self.markSide)
                        .offset(y: revealOffset)
                        .frame(height: Self.markSide, alignment: .top)
                )

            BowlMark().fill(BrandTone.onBrand.bowl)

            if !reduceMotion {
                // §3's Reduce Motion table does not merely hold this still — it
                // does not render it at all.
                Capsule()
                    .fill(Color.white)
                    .opacity(bandOpacity)
                    .frame(width: 21 * Self.unit, height: 2 * Self.unit)
                    .offset(y: Self.bandOffset(for: bandUnitY))
            }
        }
    }

    /// §3 gives the band's travel as grid units −2 → +20, but a `ZStack` centres
    /// its children, so a raw `.offset` of −2 units would put the band at unit 10
    /// — already past the dome before the reveal starts. Read from the top of the
    /// box instead, which is the only reading where the band and the reveal edge
    /// cross the dome together, and converted back to a centre-relative offset
    /// here.
    private static func bandOffset(for unitY: CGFloat) -> CGFloat {
        (unitY - 12) * unit
    }

    /// §3's keyframe table, to the millisecond. `timingCurve`, never a spring —
    /// nothing may overshoot and settle back.
    private func runFullTimeline() async {
        // Invisible either way: the mask still covers the dome completely.
        domeOpacity = 1

        // 0–80: hold frame 0, covering the hand-off from the launch screen.
        try? await Task.sleep(for: .milliseconds(80))

        // 80→140 the band lights up, 80→520 it sweeps the whole mark.
        withAnimation(.linear(duration: 0.06)) { bandOpacity = 0.42 }
        withAnimation(.timingCurve(0.3, 0, 0.3, 1, duration: 0.44)) { bandUnitY = 20 }

        // 120→560: the dome comes out from under the mask, 40ms behind the band.
        try? await Task.sleep(for: .milliseconds(40))
        withAnimation(.timingCurve(0.3, 0, 0.3, 1, duration: 0.44)) { revealOffset = 0 }

        // 380→660: the wordmark fades in and settles up by 6pt.
        try? await Task.sleep(for: .milliseconds(260))
        withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.28)) {
            wordmarkOpacity = 1
            wordmarkOffset = 0
        }

        // 460→520: the band goes out as it leaves the bowl.
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.linear(duration: 0.06)) { bandOpacity = 0 }

        // 660–740 hold, then 740→860 the whole overlay leaves.
        try? await Task.sleep(for: .milliseconds(280))
        withAnimation(.timingCurve(0.4, 0, 1, 1, duration: 0.12)) { overlayOpacity = 0 }
        try? await Task.sleep(for: .milliseconds(120))
    }

    /// §3's Reduce Motion table — 650ms, same frame 0, so the launch image does
    /// not change. No band, no sliding mask: the mask is open from the start and
    /// the dome simply fades up.
    private func runReducedTimeline() async {
        revealOffset = 0
        domeOpacity = 0
        // Set, not animated: `wordmarkOffset` is the full timeline's *starting
        // pose*, and a path that skips the animation has to take the resting
        // value instead of inheriting the pose. Without this the wordmark sits
        // 6pt below where §3 puts it for the whole 650ms — a layout difference
        // that Reduce Motion never asked for, only a motion one.
        wordmarkOffset = 0

        withAnimation(.linear(duration: 0.25)) {
            domeOpacity = 1
            wordmarkOpacity = 1
        }

        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.linear(duration: 0.20)) { overlayOpacity = 0 }
        try? await Task.sleep(for: .milliseconds(200))
    }
}

#Preview("Splash") {
    SplashOverlay {}
}
