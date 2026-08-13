import SwiftUI

/// A meal's photo at thumbnail size, or something else in its place.
///
/// Three places on the History screen need this — the chips on a day card, a search
/// result and a row of the day panel — at three sizes, and each of them needs the
/// *same* two guarantees: the square is exactly as big with a photo as without it
/// (§0.2, the rule the whole screen rests on), and the bytes are decoded from what
/// `MealPhotoStore` already downsampled rather than from the 1,600px original.
///
/// The fallback is a `ViewBuilder` rather than a `String` because the three callers
/// disagree about it: a chip shows the dish's first letter, a result its meal-type
/// glyph. What they must not disagree about is the geometry.
struct MealThumbnail<Fallback: View>: View {
    let photoID: UUID?
    let side: CGFloat
    let radius: CGFloat
    @ViewBuilder var fallback: Fallback

    @Environment(DependencyContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                DS.chipOnBg
                fallback
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        // §7: the square carries nothing its row's combined label does not say.
        .accessibilityHidden(true)
        // The photo arrives after the row is on screen, so it fades in rather than
        // snapping — unless the user asked for less motion.
        .animation(reduceMotion ? nil : .easeIn(duration: 0.18), value: thumbnail == nil)
        // Keyed on the id, so a row reused for a different meal reloads and a meal
        // with no photo never asks. Cancelled when the row scrolls away, which is why
        // the result is checked before it is used.
        .task(id: photoID) { await load() }
    }

    private func load() async {
        guard let photoID else {
            thumbnail = nil
            return
        }
        let data = await container.photoStore.thumbnailData(for: photoID)
        guard !Task.isCancelled else { return }
        thumbnail = data.flatMap(UIImage.init(data:))
    }
}
