import SwiftUI

enum DSButtonVariant {
    case primary, accent, secondary, ghost, subtle
}

enum DSButtonSize {
    case small, medium, large

    var height: CGFloat {
        switch self {
        case .small: 34
        case .medium: 42
        case .large: 52
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: 14
        case .medium: 20
        case .large: 28
        }
    }

    var font: Font {
        switch self {
        case .small: Font.custom(DSFontName.semibold, size: 14, relativeTo: .subheadline)
        case .medium: Font.custom(DSFontName.semibold, size: 15, relativeTo: .body)
        case .large: Font.custom(DSFontName.semibold, size: 17, relativeTo: .body)
        }
    }

    var radius: CGFloat {
        switch self {
        case .small: Radius.sm
        default: Radius.md
        }
    }
}

/// Brand button. Blue `primary` leads; orange `accent` is reserved for the
/// single most important action on a surface. Ported from `Button.jsx`.
///
/// Web hover states have no iOS equivalent, so the upstream `:hover` colours
/// are dropped and `:active` becomes the pressed state — including the 1pt
/// downward nudge.
struct DSButtonStyle: ButtonStyle {
    var variant: DSButtonVariant = .primary
    var size: DSButtonSize = .medium
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, variant: variant, size: size, fullWidth: fullWidth)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let variant: DSButtonVariant
        let size: DSButtonSize
        let fullWidth: Bool

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(size.font)
                .kerning(-0.15) // --tracking-snug
                // §9's type scale is Dynamic-Type-aware throughout, and this
                // button was the one element that could not follow it:
                // `lineLimit(1)` forbade wrapping while `frame(height:)` refused
                // to grow, so "Kết nối Apple Health" and "Xác nhận bữa ăn"
                // truncated mid-word at larger accessibility sizes. Two lines and
                // a minimum height instead — the label still fits one line at
                // every ordinary size, so nothing moves for most users.
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(foreground)
                .frame(minHeight: size.height)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.vertical, DS.s2)
                .padding(.horizontal, size.horizontalPadding)
                .background(background, in: shape)
                .overlay {
                    if let border {
                        shape.strokeBorder(border, lineWidth: variant == .secondary ? 1.5 : 1)
                    }
                }
                .opacity(isEnabled ? 1 : 0.5)
                .offset(y: configuration.isPressed ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: size.radius, style: .continuous)
        }

        private var pressed: Bool { configuration.isPressed }

        private var background: Color {
            switch variant {
            case .primary:
                pressed ? DSColor.actionPrimaryPressed : DSColor.actionPrimary
            case .accent:
                pressed ? DSColor.actionAccentPressed : DSColor.actionAccent
            case .secondary:
                pressed ? Color.dsAdaptive(light: 0xE2F0FB, dark: 0x0E2C46) : DSColor.surfaceCard
            case .ghost:
                pressed ? Color.dsAdaptive(light: 0xF1F7FD, dark: 0x0E2C46) : .clear
            case .subtle:
                pressed
                    ? Color.dsAdaptive(light: 0xE2F0FB, dark: 0x14344F)
                    : Color.dsAdaptive(light: 0xF1F7FD, dark: 0x0E2C46)
            }
        }

        private var foreground: Color {
            switch variant {
            case .primary, .accent: DSColor.textOnBrand
            case .secondary, .ghost, .subtle: DSColor.brandOnSurface
            }
        }

        private var border: Color? {
            variant == .secondary ? DSColor.borderBrand : nil
        }
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    static var dsPrimary: DSButtonStyle { DSButtonStyle(variant: .primary) }
    static var dsAccent: DSButtonStyle { DSButtonStyle(variant: .accent) }
    static var dsSecondary: DSButtonStyle { DSButtonStyle(variant: .secondary) }
    static var dsGhost: DSButtonStyle { DSButtonStyle(variant: .ghost) }

    static func ds(
        _ variant: DSButtonVariant,
        size: DSButtonSize = .medium,
        fullWidth: Bool = false
    ) -> DSButtonStyle {
        DSButtonStyle(variant: variant, size: size, fullWidth: fullWidth)
    }
}
