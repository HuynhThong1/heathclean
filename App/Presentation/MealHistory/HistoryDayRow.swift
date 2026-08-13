import Domain
import SwiftUI

/// One logged day in the history list.
///
/// This replaced a 44pt calendar cell (`HistoryDayTile`, deleted). The grid drew
/// every day of the month, so almost all of it was days with nothing on them —
/// and since MVP does not allow back-dating, tapping one of those opened a sheet
/// that could only say "nothing here". A row per logged day carries the same
/// picture *and* the figures that are the point of the screen.
///
/// Two states, not three: the day has a photo, or it does not and shows its date
/// on a tint. There is no empty state, because an empty day is not a row.
struct HistoryDayRow: View {
    let day: HistoryDay
    let isToday: Bool
    let onSelect: () -> Void

    static let thumbnailSide: CGFloat = 52

    @Environment(DependencyContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.s3) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(VietnameseDate.dayText(for: day.date))
                        .font(.custom(DSFontName.semibold, size: 14.5))
                        .foregroundStyle(DS.textStrong)
                    Text(summary)
                        .font(.custom(DSFontName.regular, size: 11.5))
                        .foregroundStyle(DS.textSubtle)
                }
                Spacer(minLength: DS.s2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.neutral300)
            }
            .padding(.horizontal, DS.s4)
            .padding(.vertical, DS.s3)
            // Without this the row only hit-tests where text is drawn, so the gap
            // before the chevron is dead space — the case CLAUDE.md records.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("history.day.\(HistoryCalendar.identifier(for: day.date))")
        // Keyed on the photo id, so a day whose picture changed reloads and a day
        // that has none never asks. The task is cancelled when the row scrolls
        // away, which is why the result is checked before it is used.
        .task(id: day.representativePhotoID) { await loadThumbnail() }
    }

    private var leading: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                DS.blue50
                Text(VietnameseDate.dayNumber(for: day.date))
                    .font(.custom(DSFontName.bold, size: 17))
                    .foregroundStyle(DS.blue700)
            }
        }
        .frame(width: Self.thumbnailSide, height: Self.thumbnailSide)
        .clipShape(RoundedRectangle(cornerRadius: DS.rControl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.rControl, style: .continuous)
                // Today keeps a mark of its own; §32.3 asks that a state never be
                // carried by colour alone, and the date beside it always spells the
                // day out.
                .strokeBorder(isToday ? DS.blueOnSurface : DS.borderSubtle, lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            if day.photoCount > 1 {
                photoCountBadge
            }
        }
        // A thumbnail arrives after the row is already on screen, so it fades
        // rather than snapping in — unless the user asked for less motion.
        .animation(reduceMotion ? nil : .easeIn(duration: 0.18), value: thumbnail == nil)
    }

    /// §32.2's "several photos" marker.
    private var photoCountBadge: some View {
        Text("×\(day.photoCount)")
            .font(.custom(DSFontName.bold, size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .frame(minHeight: 14)
            .background(Color.black.opacity(0.55), in: Capsule())
            .padding(3)
            // The count is in the row's own label, which is the one element
            // VoiceOver sees.
            .accessibilityHidden(true)
    }

    /// "1.681 kcal · 3 bữa". The calorie total leads because it is what the screen
    /// is for; the meal count is context.
    private var summary: String {
        String(localized: "\(VNNumber.int(day.calories)) kcal · \(day.meals.count) bữa")
    }

    /// Says everything the row draws, including whether it has a picture — §32.6
    /// asks that the states be distinguishable by VoiceOver, and a photo is
    /// otherwise invisible to it.
    private var accessibilityLabel: String {
        let date = VietnameseDate.dayText(for: day.date)
        let base = String(
            localized: "\(date), \(day.meals.count) bữa, \(VNNumber.int(day.calories)) kcal"
        )
        switch day.photoCount {
        case 0: return base
        case 1: return base + String(localized: ", có ảnh")
        default: return base + String(localized: ", có \(day.photoCount) ảnh")
        }
    }

    /// The thumbnail is decoded from bytes the store already downsampled to 240px.
    /// The original is never decoded here — that happens inside `MealPhotoStore`,
    /// off the main actor, as §32.6 requires.
    private func loadThumbnail() async {
        guard let id = day.representativePhotoID else {
            thumbnail = nil
            return
        }
        let data = await container.photoStore.thumbnailData(for: id)
        guard !Task.isCancelled else { return }
        thumbnail = data.flatMap(UIImage.init(data:))
    }
}
