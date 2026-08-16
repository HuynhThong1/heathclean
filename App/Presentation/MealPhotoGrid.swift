import Domain
import SwiftUI

/// The photos of a day or of a single meal, at a size worth looking at.
///
/// Shared by the history day sheet and the meal detail screen, so the layout rule
/// and the loading behaviour exist once. Draws nothing when there are no photos,
/// which is the common case — a meal typed in by hand never has one.
///
/// **A grid, never a sideways scroll.** The strip this replaced put three photos in
/// a row that ran off the right edge, so the day arrived half cut off behind a
/// gesture nothing announced. Every photo is on screen at once: one fills the width
/// at its own aspect ratio, two or three share a row, four or more go two to a row.
///
/// The single photo is the only one that keeps its shape; equal cells have to crop,
/// which is the price of a grid and is why one photo does not pay it.
struct MealPhotoGrid: View {
    let photos: [MealPhoto]
    /// Accessibility identifiers become `<prefix>.0`, `<prefix>.1`, … so each
    /// screen names its own.
    let identifierPrefix: String

    /// **150pt, not the 240 it started at.** A square photo at 240 pushed the
    /// calorie total and the meal rows below the day sheet's medium detent, so the
    /// sheet opened on a picture and nothing else. The numbers are what §32.2 asks
    /// that sheet for; the photo is what makes the day recognisable.
    static let singleHeight: CGFloat = 150

    var body: some View {
        if photos.count == 1, let only = photos.first {
            MealPhotoTile(photo: only, identifier: "\(identifierPrefix).0", crops: false)
                .frame(maxHeight: Self.singleHeight)
        } else if photos.count > 1 {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(minimum: 0), spacing: DS.s2),
                    count: photos.count <= 3 ? photos.count : 2
                ),
                spacing: DS.s2
            ) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    MealPhotoTile(
                        photo: photo,
                        identifier: "\(identifierPrefix).\(index)",
                        crops: true
                    )
                }
            }
        }
    }
}

/// One photo, loaded at preview size off the main actor.
///
/// It keeps its own aspect ratio from `MealPhoto`'s pixel size, so the card is the
/// right shape *before* the bytes arrive and the layout does not jump when they do.
/// That is the whole reason the pixel dimensions are in the model.
private struct MealPhotoTile: View {
    let photo: MealPhoto
    let identifier: String
    /// A grid cell is square and crops to fill it; a lone photo keeps its shape.
    let crops: Bool

    @Environment(DependencyContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    /// Separate from `image == nil`, so a photo whose file is gone shows the
    /// placeholder for good instead of an eternal loading state.
    @State private var didLoad = false

    private var aspectRatio: Double {
        guard photo.pixelWidth > 0, photo.pixelHeight > 0 else { return 1 }
        return Double(photo.pixelWidth) / Double(photo.pixelHeight)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                DS.neutral150
                if didLoad {
                    // The file is gone. Says so quietly rather than failing the
                    // screen — §32.3's rule for a missing photo.
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(DS.textSubtle)
                }
            }
        }
        .aspectRatio(crops ? 1 : aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DS.rCard, style: .continuous))
        .animation(reduceMotion ? nil : .easeIn(duration: 0.18), value: image == nil)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier(identifier)
        .task(id: photo.id) {
            let data = await container.photoStore.previewData(for: photo.id)
            guard !Task.isCancelled else { return }
            image = data.flatMap(UIImage.init(data:))
            didLoad = true
        }
    }

    private var accessibilityLabel: String {
        L("Ảnh bữa ăn lúc \(AppDate.time(for: photo.capturedAt))")
    }
}
