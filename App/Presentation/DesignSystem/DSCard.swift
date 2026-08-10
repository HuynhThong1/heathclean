import SwiftUI

enum DSCardPadding {
    case none, small, medium, large

    var value: CGFloat {
        switch self {
        case .none: 0
        case .small: 16
        case .medium: 24
        case .large: 32
        }
    }
}

enum DSAccent {
    case blue, orange, green

    var color: Color {
        switch self {
        case .blue: DSPalette.fptBlue
        case .orange: DSPalette.fptOrange
        case .green: DSPalette.fptGreen
        }
    }
}

/// Container surface with soft shadow and rounded corners. `accent` draws the
/// 4pt brand bar along the top edge. Ported from `Card.jsx`.
struct DSCard<Content: View>: View {
    private let padding: DSCardPadding
    private let accent: DSAccent?
    private let content: Content

    init(
        padding: DSCardPadding = .medium,
        accent: DSAccent? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding.value)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSColor.surfaceCard)
            .overlay(alignment: .top) {
                if let accent {
                    Rectangle()
                        .fill(accent.color)
                        .frame(height: 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(DSColor.borderSubtle, lineWidth: 1)
            }
            .dsShadow(.sm)
    }
}
