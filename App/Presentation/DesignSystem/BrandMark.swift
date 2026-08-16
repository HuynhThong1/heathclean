import SwiftUI

/// BRAND_SPEC §1 — the mark, rebuilt as `Path` rather than imported as SVG.
///
/// Two shapes and nothing else: a filled bowl and a stroked dome over it. No
/// gradient, no shadow, no stroke on the bowl, in any variant. Everything is
/// expressed against a 24×24 grid and scaled by `s`, so one geometry serves
/// 16pt and 1024px alike.
///
/// **The spec's own Swift snippet draws the bowl upside down and this does not.**
/// It passes `clockwise: false` to both arcs, but the two need opposite sweeps:
/// SwiftUI's flag is read in a y-down space, where the bowl has to pass 90°
/// (screen bottom) and the dome 270° (screen top). Measured rather than argued —
/// `boundingRect` of the bowl is y 4…13 with the spec's flag, the upper half, and
/// y 13…22 with this one. The spec's *SVG* is right and says so: the bowl is
/// `A9 9 0 0 0` and the dome `A8.2 8.2 0 0 1`, sweep flags that already disagree.
struct BowlMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()
        path.move(to: CGPoint(x: 3 * s, y: 13 * s))
        path.addArc(
            center: CGPoint(x: 12 * s, y: 13 * s),
            radius: 9 * s,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

/// The dome. Stroked, never filled — `BrandMark` sets the width to `2.6 * s`, so
/// the weight scales with the mark instead of thinning out at 132pt.
struct DomeArc: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()
        path.addArc(
            center: CGPoint(x: 12 * s, y: 13 * s),
            radius: 8.2 * s,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        return path
    }
}

// MARK: - Tone

/// §1's colour table. Four contexts, and the mark is the same geometry in all of
/// them.
///
/// **These resolve to absolute values, not to the adaptive `DS.*` semantics.** A
/// tone is already a statement about the surface the mark sits on, so reading
/// `DS.textStrong` here would apply the appearance twice: a `.light` lockup on a
/// white card would draw near-white in dark mode. That is exactly the bug
/// `DSButtonStyle` hit, where Apple Health's "Để sau" ended up at 1.9:1. The
/// absolute values live in `DesignTokens.swift` beside the brand colours, so no
/// hex is written in a view.
enum BrandTone {
    /// On `#F4F7FA` or a white card.
    case light
    /// On the dark page. Only the bowl turns white; the dome keeps brand blue.
    case dark
    /// On brand blue itself — the splash and the app icon.
    case onBrand
    /// Watermark, print, disabled.
    case mono

    var bowl: Color {
        switch self {
        case .light: DS.blue
        case .dark: .white
        case .onBrand: .white
        case .mono: DS.logoMono
        }
    }

    var dome: Color {
        switch self {
        case .light: DS.blue
        case .dark: DS.blue
        case .onBrand: .white
        case .mono: DS.logoMono
        }
    }

    var wordmark: Color {
        switch self {
        case .light: DS.logoInk
        case .dark: DS.logoPaper
        case .onBrand: DS.logoPaper
        case .mono: DS.logoMono
        }
    }
}

// MARK: - Mark

/// The two shapes together, at an explicit side.
///
/// The side is a parameter rather than read from a `GeometryReader` because every
/// caller already knows it — §1 gives the lockup's proportions in terms of the
/// mark height `h`, and the splash and the icons are given exact point sizes.
struct BrandMark: View {
    let side: CGFloat
    var tone: BrandTone = .light
    /// How much of the dome is drawn. The splash animates this from 0; everywhere
    /// else it is the whole arc.
    var domeTrim: CGFloat = 1

    var body: some View {
        ZStack {
            BowlMark().fill(tone.bowl)
            DomeArc()
                .trim(from: 0, to: domeTrim)
                .stroke(
                    tone.dome,
                    style: StrokeStyle(lineWidth: Self.domeLineWidth(side: side), lineCap: .round)
                )
        }
        .frame(width: side, height: side)
    }

    /// §1: `lineWidth = 2.6 * side / 24`.
    static func domeLineWidth(side: CGFloat) -> CGFloat { 2.6 * side / 24 }

    /// Where the **bowl's** centre sits relative to the centre of the mark's box,
    /// as a fraction of the side.
    ///
    /// The bowl occupies y 13…22 of the 24 grid, so its centre is at 17.5 — 5.5
    /// units below the box centre at 12. The launch screen shows the bowl alone
    /// and the splash shows the whole mark, and they have to agree to the point:
    /// this is what lets the splash place its box so the bowl lands exactly where
    /// the static image drew it.
    static let bowlCentreOffsetRatio: CGFloat = 5.5 / 24

    /// The bowl spans x 3…21 and y 13…22 of the grid, so it is twice as wide as it
    /// is tall. §2 sizes the launch image by the **bowl's** width, not the mark's.
    static let bowlWidthRatio: CGFloat = 18 / 24
}

// MARK: - Previews

#Preview("Mark · 16 / 24 / 40 / 132") {
    VStack(spacing: 28) {
        ForEach([BrandTone.light, .dark, .onBrand, .mono], id: \.self) { tone in
            HStack(alignment: .bottom, spacing: 20) {
                ForEach([16.0, 24.0, 40.0, 132.0], id: \.self) { side in
                    BrandMark(side: side, tone: tone)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(previewBackground(for: tone))
        }
    }
    .padding(.vertical, 20)
}

/// 16pt is §1's floor, so the preview draws it against the grid it has to survive:
/// at that size the dome is a 1.7pt stroke and the two shapes nearly touch.
#Preview("Mark · 16pt floor") {
    HStack(spacing: 12) {
        ForEach([14.0, 16.0, 18.0, 20.0], id: \.self) { side in
            VStack(spacing: 6) {
                BrandMark(side: side, tone: .light)
                Text(verbatim: "\(Int(side))")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.textSubtle)
            }
        }
    }
    .padding(24)
    .background(DS.surfacePage)
}

@ViewBuilder
private func previewBackground(for tone: BrandTone) -> some View {
    switch tone {
    case .light: DS.surfacePage
    case .dark: Color(hex: 0x0B1219)
    case .onBrand: DS.blue
    case .mono: DS.surfacePage
    }
}

extension BrandTone: Hashable {}
