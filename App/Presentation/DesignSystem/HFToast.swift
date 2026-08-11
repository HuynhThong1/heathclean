import SwiftUI

/// Confirmation toast — handoff §6.14. Dark pill, green check, fades and rises
/// in, auto-dismisses after 2.6s.
struct HFToast: View {
    let text: String

    var body: some View {
        HStack(spacing: DS.s2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.green400)
            Text(text)
                .font(.custom(DSFontName.semibold, size: 13.5))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, DS.s4)
        .padding(.vertical, DS.s3)
        .background(DS.neutral900, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color(hex: 0x0F1B27).opacity(0.3), radius: 15, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("toast")
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    HFToast(text: message)
                        .padding(.horizontal, DS.s4)
                        // §6.14's 104pt, which is there to clear the tab bar.
                        // This was 34pt while the app had no tab bar; once §5
                        // landed the toast was composited over the bar and sat
                        // squarely on the raised orange scan button for 2.6s.
                        .padding(.bottom, 104)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(2.6))
                            withAnimation(DS.ease) { self.message = nil }
                        }
                }
            }
            .animation(DS.ease, value: message)
    }
}

extension View {
    /// Shows a toast while `message` is non-nil, clearing it after 2.6s.
    func hfToast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
