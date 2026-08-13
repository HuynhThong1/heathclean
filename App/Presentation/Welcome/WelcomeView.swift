import SwiftUI

/// Welcome — handoff §6.1. The first-run entry: full-bleed brand gradient,
/// content pinned top and bottom.
struct WelcomeView: View {
    let onStart: () -> Void

    /// The pinned layout has to be able to give up and scroll.
    ///
    /// Every `Font.custom(_:size:)` here scales with Dynamic Type, so at an
    /// accessibility text size the copy grew until "Bắt đầu" sat below the screen
    /// — on a fixed `VStack` with no way to reach it, which locks a user at that
    /// text size out of the app entirely at the first screen. A UI test for §32
    /// found it by failing to tap that button.
    ///
    /// `minHeight: proxy.size.height` keeps the `Spacer`s doing their job when the
    /// content fits, and `.basedOnSize` means there is no bounce then either — at
    /// ordinary sizes this is the same screen it was.
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: proxy.size.height,
                        alignment: .leading
                    )
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(brandGradient.ignoresSafeArea())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            logoRow
                .padding(.top, DS.s5)

            Spacer(minLength: DS.s6)

            VStack(alignment: .leading, spacing: DS.s4) {
                Text("DINH DƯỠNG HẰNG NGÀY")
                    .font(.custom(DSFontName.bold, size: 11))
                    .tracking(1.76) // 0.16em at 11pt
                    .foregroundStyle(.white.opacity(0.7))

                Text("Chụp bữa ăn.\nBiết ngay calo.")
                    .font(.custom(DSFontName.extrabold, size: 38))
                    .tracking(-0.95) // −0.025em
                    .lineSpacing(0)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("AI nhận diện món ăn, cơ sở dữ liệu dinh dưỡng tính calo, và bạn là người xác nhận cuối cùng.")
                    .font(.custom(DSFontName.regular, size: 15))
                    .lineSpacing(15 * 0.55)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: 300, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: DS.s2) {
                    checkLine("Dữ liệu sức khỏe lưu trên thiết bị")
                    checkLine("Món Việt: cơm tấm, phở, bánh mì…")
                }
                .padding(.top, DS.s2)
            }

            Spacer(minLength: DS.s6)

            VStack(spacing: DS.s3) {
                Button("Bắt đầu") { onStart() }
                    .buttonStyle(.ds(.accent, size: .large, fullWidth: true))
                    .accessibilityIdentifier("welcome.start")

                // §6.1 also specifies a "Tôi đã có tài khoản" link. Omitted:
                // there is no account system to sign into, and a link that
                // cannot do what it says is worse than an absent one. Add it
                // back with accounts.
            }
            .padding(.bottom, DS.s4)
        }
    }

    private var logoRow: some View {
        HStack(spacing: DS.s3) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    .white.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
            Text("HealthClean")
                .font(.custom(DSFontName.bold, size: 17))
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HealthClean")
    }

    private func checkLine(_ text: String) -> some View {
        HStack(spacing: DS.s2) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            Text(text)
                .font(.custom(DSFontName.regular, size: 14))
                .foregroundStyle(.white.opacity(0.9))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// `linear-gradient(160deg, #004E8C 0%, #0062B0 55%, #0E9F43 140%)`.
    /// 160° in CSS runs top-ish to bottom-ish; the 140% stop is clamped to 1,
    /// so the green only just arrives at the bottom edge — as it does on the
    /// design board.
    private var brandGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0x004E8C), location: 0),
                .init(color: Color(hex: 0x0062B0), location: 0.55),
                .init(color: Color(hex: 0x0E9F43), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottomTrailing
        )
    }
}
