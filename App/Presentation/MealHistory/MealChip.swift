import Domain
import SwiftUI

/// One meal on a history day card: a 26pt square, the dish name and a line of
/// meta (HISTORY_SPEC §2, §4).
///
/// **A chip with a photo and a chip without are exactly the same size**, which is
/// §0.2 and the reason this screen works at all: most meals are typed in and have
/// no picture, so a layout that grows a photo cell would leave the row of chips
/// looking half-empty on the ordinary day. The square is either the thumbnail or
/// the dish's first letter on a blue tint — same 26×26, same corner.
///
/// It is deliberately **not** a button. §4 puts one tap target on the whole card:
/// three 38pt chips inside a 44pt row would be a mis-tap waiting to happen, and
/// the way to a meal is through the day panel.
struct MealChip: View {
    let name: String
    /// "06:50 · 480 kcal".
    let meta: String
    /// `nil` for the common case — a meal with no photo.
    let photoID: UUID?

    static let squareSide: CGFloat = 26

    var body: some View {
        HStack(spacing: 7) {
            square
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.custom(DSFontName.semibold, size: 12))
                    .foregroundStyle(DS.textStrong)
                    .lineLimit(2)
                Text(meta)
                    .font(.custom(DSFontName.regular, size: 10.5))
                    .foregroundStyle(DS.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .frame(minHeight: 38)
        .background(DS.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: DS.rControl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                .strokeBorder(DS.borderSubtle, lineWidth: 1)
        }
    }

    private var square: some View {
        MealThumbnail(photoID: photoID, side: Self.squareSide, radius: 7) {
            Text(monogram)
                .font(.custom(DSFontName.bold, size: 12))
                .foregroundStyle(DS.blueOnSurface)
                // The square is a fixed size so photo and monogram chips match, so
                // the letter has to give way rather than clip at accessibility text
                // sizes.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(2)
        }
    }

    /// The dish's first letter. Not initials of every word: "Bánh mì trứng" is
    /// one dish, and "BMT" reads as an abbreviation of something else.
    private var monogram: String {
        guard let first = name.first(where: { !$0.isWhitespace }) else { return "•" }
        return String(first).uppercased()
    }
}

/// "+2 món" — the chip that stands for the meals a card does not have room to
/// name (§4: three chips, then this).
///
/// No square, because there is no one dish behind it to show a letter or a photo
/// for; a monogram box here would imply a fourth dish called "+2".
struct MealChipMore: View {
    let count: Int

    var body: some View {
        Text("+\(count) món")
            .font(.custom(DSFontName.semibold, size: 12))
            .foregroundStyle(DS.textMuted)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: 38)
            .background(DS.surfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: DS.rControl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                    .strokeBorder(DS.borderSubtle, lineWidth: 1)
            }
    }
}

#if DEBUG
    #Preview("Meal chips") {
        VStack(alignment: .leading, spacing: DS.s4) {
            // Same size with and without a photo — §0.2. Nothing is written to the
            // photo store in a preview, so the first chip falls back to its
            // monogram; the point on show here is the geometry.
            HStack(spacing: DS.s2) {
                MealChip(name: "Phở bò", meta: "06:50 · 480 kcal", photoID: UUID())
                MealChip(name: "Cơm gà", meta: "12:20 · 720 kcal", photoID: nil)
            }
            HStack(spacing: DS.s2) {
                MealChip(name: "Sữa chua", meta: "15:40 · 180 kcal", photoID: nil)
                MealChipMore(count: 2)
            }
            MealChip(
                name: "Bánh mì trứng ốp la",
                meta: "08:00 · 420 kcal",
                photoID: nil
            )
            MealChip(name: "3 món", meta: "19:30 · 1.190 kcal", photoID: nil)
                .environment(\.dynamicTypeSize, .accessibility3)
        }
        .padding(DS.s5)
        .background(DS.surfaceCard)
        .environment(DependencyContainer(inMemory: true))
    }
#endif
