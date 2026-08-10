import SwiftUI
import UIKit

extension UIColor {
    fileprivate convenience init(dsHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// A fixed brand value — identical in light and dark.
    static func dsFixed(_ hex: UInt32) -> Color {
        Color(UIColor(dsHex: hex))
    }

    /// Resolves per appearance. Used by the semantic layer only; the raw ramps
    /// below are absolute brand values and never vary.
    static func dsAdaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(dsHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

/// Raw colour ramps, ported verbatim from the FPT IS design system
/// (`tokens/colors.css`). These are absolute values — prefer `DSColor`, the
/// semantic layer, in application code.
///
/// The three-colour mark drives the identity: blue leads, orange energizes,
/// green grounds.
enum DSPalette {
    // MARK: Brand core

    static let fptBlue = Color.dsFixed(0x0062B0)
    static let fptOrange = Color.dsFixed(0xF37021)
    static let fptGreen = Color.dsFixed(0x12B24C)

    // MARK: Blue ramp (primary)

    static let blue900 = Color.dsFixed(0x002E52)
    static let blue800 = Color.dsFixed(0x003F71)
    static let blue700 = Color.dsFixed(0x004E8C)
    static let blue600 = Color.dsFixed(0x0062B0)
    static let blue500 = Color.dsFixed(0x1A7CCB)
    static let blue400 = Color.dsFixed(0x4D9BDB)
    static let blue300 = Color.dsFixed(0x86BEEA)
    static let blue200 = Color.dsFixed(0xBEDCF4)
    static let blue100 = Color.dsFixed(0xE2F0FB)
    static let blue50 = Color.dsFixed(0xF1F7FD)

    // MARK: Orange ramp (accent)

    static let orange700 = Color.dsFixed(0xC4520E)
    static let orange600 = Color.dsFixed(0xE0611A)
    static let orange500 = Color.dsFixed(0xF37021)
    static let orange400 = Color.dsFixed(0xF78F4F)
    static let orange300 = Color.dsFixed(0xFBB183)
    static let orange200 = Color.dsFixed(0xFDD3B8)
    static let orange100 = Color.dsFixed(0xFDEADC)

    // MARK: Green ramp (support)

    static let green700 = Color.dsFixed(0x0A7D34)
    static let green600 = Color.dsFixed(0x0E9640)
    static let green500 = Color.dsFixed(0x12B24C)
    static let green400 = Color.dsFixed(0x47C674)
    static let green300 = Color.dsFixed(0x83DAA1)
    static let green200 = Color.dsFixed(0xBEECCE)
    static let green100 = Color.dsFixed(0xE4F7EB)

    // MARK: Neutrals (cool grey, tuned toward the blue)

    static let neutral900 = Color.dsFixed(0x0F1B27)
    static let neutral800 = Color.dsFixed(0x1F2E3D)
    static let neutral700 = Color.dsFixed(0x35485A)
    static let neutral600 = Color.dsFixed(0x506173)
    static let neutral500 = Color.dsFixed(0x6E7F90)
    static let neutral400 = Color.dsFixed(0x94A3B2)
    static let neutral300 = Color.dsFixed(0xC0CAD4)
    static let neutral200 = Color.dsFixed(0xDDE4EA)
    static let neutral150 = Color.dsFixed(0xE9EEF2)
    static let neutral100 = Color.dsFixed(0xF2F5F8)
    static let neutral50 = Color.dsFixed(0xF8FAFC)

    // MARK: Semantic status

    static let success = green600
    static let warning = Color.dsFixed(0xE8A317)
    static let danger = Color.dsFixed(0xD5342B)
    static let info = blue500
}
