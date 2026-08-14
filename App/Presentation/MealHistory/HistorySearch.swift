import Domain
import SwiftUI

/// The seven filter chips of HISTORY_SPEC §5, in its order.
///
/// `all` is not a filter but the absence of them, which is why it "excludes the
/// others" rather than combining: it is the reset, drawn as a chip so the row reads
/// as a set of states rather than as five switches with no off.
enum HistoryFilter: String, CaseIterable, Identifiable {
    case all, hasPhoto, overBudget, breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var vi: String {
        switch self {
        case .all: "Tất cả"
        case .hasPhoto: "Có ảnh"
        case .overBudget: "Vượt mục tiêu"
        case .breakfast: MealType.breakfast.vi
        case .lunch: MealType.lunch.vi
        case .dinner: MealType.dinner.vi
        case .snack: MealType.snack.vi
        }
    }

    /// The four chips that pick a meal of the day. `nil` for the other three, which
    /// is what makes them a separate group in §5's AND-of-ORs.
    var mealType: MealType? {
        switch self {
        case .breakfast: .breakfast
        case .lunch: .lunch
        case .dinner: .dinner
        case .snack: .snack
        default: nil
        }
    }
}

/// Diacritic- and case-insensitive matching, per §5: "pho" finds "phở", and so does
/// "PHO".
///
/// The Vietnamese locale is passed explicitly rather than taken from the device: the
/// app's copy is Vietnamese wherever the phone is set, so its folding rules have to
/// be too — the same reason `VNNumber` pins `vi_VN`.
enum HistorySearchText {
    static let minimumQueryLength = 2

    private static let locale = Locale(identifier: "vi_VN")

    static func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
    }

    /// `query` is expected already folded — callers fold it once per keystroke
    /// rather than once per food name.
    static func contains(foldedQuery query: String, in text: String) -> Bool {
        folded(text).contains(query)
    }
}

/// One meal that matched, ready to draw (§5).
///
/// It carries its own title because the row shows **what matched** — searching "phở"
/// on a three-dish lunch should name the phở, not the whole lunch.
struct HistoryMealHit: Identifiable, Equatable {
    let meal: Meal
    /// Start of the day it was logged on, so tapping the row can open that day.
    let dayDate: Date
    let title: String

    var id: UUID { meal.id }
}

/// The pinned search field (§2, §5). Not a sheet and not a navigation-bar
/// searchable: it sits in the header so the keyword and the chips are visible
/// together, and so clearing it is one tap from wherever the list has scrolled to.
struct HistorySearchField: View {
    @Binding var text: String

    private var isFilled: Bool { !text.isEmpty }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isFilled ? DS.blueOnSurface : DS.textSubtle)
                .accessibilityHidden(true)

            TextField(text: $text) {
                Text("Tìm món ăn, ví dụ: phở")
                    .foregroundStyle(DS.textSubtle)
            }
            .font(.custom(DSFontName.regular, size: 14.5))
            .foregroundStyle(DS.textStrong)
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .accessibilityLabel("Tìm món ăn")
            .accessibilityIdentifier("field.historySearch")

            if isFilled {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DS.neutral300)
                        // §4's floor applies to this too: the glyph is 18pt and the
                        // target is 44. It is a real 44pt frame rather than an 18pt
                        // one with a `contentShape` around it, because a shape drawn
                        // outside its own layout frame is not reliably hit-tested.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Xoá từ khoá")
                .accessibilityIdentifier("history.search.clear")
            }
        }
        .padding(.leading, DS.s3)
        // The clear button brings its own 44pt of width, which puts the glyph 13pt
        // from the edge — §2's 12pt inset, near enough, and a full-size target.
        .padding(.trailing, isFilled ? 0 : DS.s3)
        .frame(minHeight: 44)
        .background(isFilled ? DS.surfaceCard : DS.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isFilled ? DS.blue : DS.borderDefault, lineWidth: 1)
        }
    }
}

/// §5's chip row. Scrolls sideways because seven chips do not fit a phone and
/// wrapping them would make the pinned header change height as they are toggled.
struct HistoryFilterChipRow: View {
    let selected: Set<HistoryFilter>
    let onToggle: (HistoryFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.s2) {
                ForEach(HistoryFilter.allCases) { filter in
                    chip(filter)
                }
            }
            // The row is inset by the header, so the scroll content only needs the
            // trailing slack that keeps the last chip clear of the edge.
            .padding(.trailing, DS.s1)
        }
    }

    private func chip(_ filter: HistoryFilter) -> some View {
        // `all` is on precisely when nothing else is, so it never needs its own bit
        // of state to keep in step.
        let isOn = filter == .all ? selected.isEmpty : selected.contains(filter)
        return Button {
            onToggle(filter)
        } label: {
            Text(filter.vi)
                .font(.custom(DSFontName.semibold, size: 12.5))
                .foregroundStyle(isOn ? DS.blueOnSurface : DS.textBody)
                .lineLimit(1)
                .padding(.horizontal, DS.s3)
                .frame(minHeight: 34)
                .background(isOn ? DS.chipOnBg : DS.surfaceCard)
                .clipShape(Capsule())
                .overlay {
                    // §5: an active "Vượt mục tiêu" is brand blue like every other
                    // chip. A grey or red one would turn a filter into a verdict.
                    Capsule().strokeBorder(isOn ? DS.blue : DS.borderDefault, lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "\(filter.vi), đang bật" : filter.vi)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("history.filter.\(filter.rawValue)")
    }
}

/// A matched meal (§5). The unit of the list changes with the keyword: no search
/// means days, a search means meals — because "which day was that" and "when did I
/// eat phở" are different questions and a day card cannot answer the second.
struct MealResultRow: View {
    let hit: HistoryMealHit
    let onSelect: () -> Void

    private static let squareSide: CGFloat = 34

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 11) {
                square
                VStack(alignment: .leading, spacing: 1) {
                    Text(hit.title)
                        .font(.custom(DSFontName.semibold, size: 13.5))
                        .foregroundStyle(DS.textStrong)
                        .lineLimit(2)
                    Text(meta)
                        .font(.custom(DSFontName.regular, size: 11.5))
                        .foregroundStyle(DS.textMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: DS.s2)
                Text(VietnameseDate.dayMonth(for: hit.dayDate))
                    .font(.custom(DSFontName.semibold, size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(DS.textBody)
            }
            .padding(11)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DS.borderSubtle, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Chạm hai lần để xem ngày này.")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("history.result.\(hit.meal.id.uuidString)")
    }

    private var square: some View {
        MealThumbnail(
            photoID: hit.meal.photos.first?.id,
            side: Self.squareSide,
            radius: 9
        ) {
            Image(systemName: hit.meal.type.chipSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.blueOnSurface)
        }
    }

    /// "Bữa sáng · 480 kcal".
    private var meta: String {
        "\(hit.meal.type.vi) · \(VNNumber.int(hit.meal.calories)) kcal"
    }

    private var accessibilityLabel: String {
        var label = String(
            localized:
                "\(VietnameseDate.spokenDayText(for: hit.dayDate)), \(hit.meal.type.vi), \(hit.title), \(VNNumber.int(hit.meal.calories)) ki-lô ca-lo."
        )
        if !hit.meal.photos.isEmpty {
            label += String(localized: " Có ảnh.")
        }
        return label
    }
}

#if DEBUG
    #Preview("Search field and chips") {
        @Previewable @State var text = "phở"
        @Previewable @State var filters: Set<HistoryFilter> = [.hasPhoto]

        return VStack(alignment: .leading, spacing: DS.s3) {
            HistorySearchField(text: .constant(""))
            HistorySearchField(text: $text)
            HistoryFilterChipRow(selected: []) { _ in }
            HistoryFilterChipRow(selected: filters) { filter in
                if filters.contains(filter) {
                    filters.remove(filter)
                } else {
                    filters.insert(filter)
                }
            }
        }
        .padding(DS.s4)
        .background(DS.surfaceCard)
    }

    #Preview("Search results") {
        let day = HistoryPreviewData.dayWithOnePhoto
        return VStack(spacing: 9) {
            ForEach(day.meals) { meal in
                MealResultRow(
                    hit: HistoryMealHit(
                        meal: meal,
                        dayDate: day.date,
                        title: HistoryDayCard.chipName(for: meal)
                    ),
                    onSelect: {}
                )
            }
        }
        .padding(DS.s4)
        .background(DS.surfacePage)
        .environment(DependencyContainer(inMemory: true))
    }
#endif
