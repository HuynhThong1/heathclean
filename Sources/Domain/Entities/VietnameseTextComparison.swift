import Foundation

/// Folds a dish name down to what should count as "the same name" (`plan.md` §22).
///
/// Trimmed, diacritic- and case-insensitive under `vi_VN`, so a user who types
/// "Pho bo" over the model's "Phở bò" is recorded as having *confirmed* the
/// dish, not corrected it. Counting that as a misidentification would inflate
/// every §29 accuracy figure with keyboard habits.
///
/// **Deliberately not `HistorySearchText`**, which folds for *substring* search
/// in the Presentation layer and does not trim. Same technique, different
/// question — merging them would tie a Domain measurement to a search box.
enum VietnameseTextComparison {
    private static let locale = Locale(identifier: "vi_VN")

    static func areSameName(_ lhs: String, _ rhs: String) -> Bool {
        folded(lhs) == folded(rhs)
    }

    private static func folded(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
    }
}
