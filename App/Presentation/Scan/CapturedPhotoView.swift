import SwiftUI

/// Confirm the photo before spending a request on it.
///
/// Not in the handoff, which goes straight from §6.6 to §6.7. It is here because
/// analysing costs one call against a small daily free-tier quota — already
/// exhausted once — and a blurry or mis-framed frame returns a confident wrong
/// dish rather than an error. It is also the first chance to see the photo the
/// way the model will: **if the food looks sideways here, EXIF orientation is the
/// culprit**, and that is the one thing about the capture path still unverified.
///
/// On the dark scan surface, because it sits between two screens that are.
struct CapturedPhotoView: View {
    let imageData: Data
    let onUse: (Data) -> Void
    let onRetake: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.s3) {
                Text("Dùng ảnh này?")
                    .font(.custom(DSFontName.bold, size: 18))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.top, DS.s4)

            Spacer(minLength: DS.s4)

            if let image = UIImage(data: imageData) {
                // The square box is sized first and the image fills it from
                // inside an overlay. Putting `.scaledToFill()` on the image and
                // an aspect ratio around it instead — which is what this was —
                // leaves the height unconstrained: the image grew until it
                // owned the whole screen, pushed the title and both buttons out
                // of it, and `.clipShape` had no definite frame to clip to.
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityLabel("Ảnh bữa ăn vừa chụp")
            } else {
                // Decoding cannot fail for a frame we just wrote, but showing an
                // empty box would be worse than saying so.
                Text("Không đọc được ảnh. Chụp lại nhé.")
                    .font(.custom(DSFontName.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, minHeight: 200)
            }

            Text("Cả đĩa ăn nằm trong khung và không bị mờ thì AI nhận diện chính xác hơn.")
                .font(.custom(DSFontName.regular, size: 12.5))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.s4)

            Spacer(minLength: DS.s4)

            VStack(spacing: DS.s3) {
                Button("Phân tích ảnh này") { onUse(imageData) }
                    .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
                    .accessibilityIdentifier("captured.use")

                // The ghost style is drawn for a light surface, so this is styled
                // here — the same reason §6.7's failure screen does.
                Button("Chụp lại", action: onRetake)
                    .buttonStyle(.plain)
                    .font(.custom(DSFontName.semibold, size: 15))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("captured.retake")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.scanSurface.ignoresSafeArea())
    }
}
