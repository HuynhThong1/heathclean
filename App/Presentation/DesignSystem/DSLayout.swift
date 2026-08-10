import SwiftUI

/// 8pt grid with 4pt half-steps, from `tokens/layout.css`.
enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32
    static let s7: CGFloat = 48
    static let s8: CGFloat = 64
}

/// Corner radii — moderately rounded, corporate rather than playful.
enum Radius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let pill: CGFloat = 999
}

/// Soft, cool-tinted elevation. CSS blur radius is roughly twice SwiftUI's, so
/// the upstream values are halved here; layered shadows stay layered.
enum DSShadow {
    case xs, sm, md, lg, brand
}

private extension Color {
    /// `rgba(15, 27, 39, …)` — the neutral-900 ink the design system shadows use.
    static func dsInk(_ opacity: Double) -> Color {
        Color(red: 15 / 255, green: 27 / 255, blue: 39 / 255).opacity(opacity)
    }

    /// `rgba(0, 98, 176, …)` — brand blue.
    static func dsBrandInk(_ opacity: Double) -> Color {
        Color(red: 0, green: 98 / 255, blue: 176 / 255).opacity(opacity)
    }
}

private struct DSShadowModifier: ViewModifier {
    let style: DSShadow

    func body(content: Content) -> some View {
        switch style {
        case .xs:
            content.shadow(color: .dsInk(0.06), radius: 1, x: 0, y: 1)
        case .sm:
            content
                .shadow(color: .dsInk(0.08), radius: 1.5, x: 0, y: 1)
                .shadow(color: .dsInk(0.04), radius: 1, x: 0, y: 1)
        case .md:
            content
                .shadow(color: .dsInk(0.08), radius: 6, x: 0, y: 4)
                .shadow(color: .dsInk(0.04), radius: 2, x: 0, y: 2)
        case .lg:
            content
                .shadow(color: .dsInk(0.12), radius: 14, x: 0, y: 12)
                .shadow(color: .dsInk(0.05), radius: 4, x: 0, y: 4)
        case .brand:
            content.shadow(color: .dsBrandInk(0.24), radius: 11, x: 0, y: 8)
        }
    }
}

extension View {
    func dsShadow(_ style: DSShadow) -> some View {
        modifier(DSShadowModifier(style: style))
    }
}
