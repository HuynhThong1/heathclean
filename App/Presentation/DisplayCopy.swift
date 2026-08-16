import Domain
import SwiftUI

/// What a Domain value is called on screen.
///
/// All of it lives in Presentation. `EvaluateCalorieBudgetUseCase` already
/// carries English message strings, but the Domain layer is not to be changed to
/// fit the UI — so the views map the *status* to copy here and leave the
/// Domain's own alone.
///
/// **Each of these used to be two properties, `vi` and `en`**, drawn one above
/// the other by `LabelPair` (handoff §4). Now that `AppLanguage` exists there is
/// one `label`, resolved through `L()`, and the English that was in `en` lives
/// in `Localizable.xcstrings` where it can be edited without touching Swift.
///
/// `label` is a resolved `String`, not a `LocalizedStringKey`: it is chosen by a
/// `switch` at runtime, so there is no literal at the call site for the catalog
/// to extract. That is what `HFLabel(verbatim:)` is for.
extension MealType {
    var label: String {
        switch self {
        case .breakfast: L("Bữa sáng")
        case .lunch: L("Bữa trưa")
        case .snack: L("Bữa phụ")
        case .dinner: L("Bữa tối")
        }
    }

    /// Chip tint, in the fixed order given by §6.4.
    var chipColor: Color {
        switch self {
        case .breakfast: DS.orange100
        case .lunch: DS.blue100
        case .snack: DS.green100
        case .dinner: DS.neutral150
        }
    }

    /// §8's icon table. Breakfast and lunch used to be two suns — `sun.horizon`
    /// and `sun.max` — which in adjacent rows of the same card read as the same
    /// glyph twice.
    var chipSymbol: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "fork.knife"
        case .snack: "cup.and.saucer"
        case .dinner: "moon"
        }
    }
}

extension ActivityLevel {
    var label: String {
        switch self {
        case .sedentary: L("Ít vận động")
        case .light: L("Nhẹ — 1–3 ngày/tuần")
        case .moderate: L("Trung bình — 3–5 ngày/tuần")
        case .active: L("Tích cực — 6–7 ngày/tuần")
        case .veryActive: L("Rất tích cực — việc thể lực")
        }
    }

    /// "×1,375" — the multiplier as shown on the activity cards (§6.2 step 2).
    @MainActor
    var multiplierText: String {
        "×" + AppNumber.upTo(fractionDigits: 3, multiplier)
    }
}

extension WeightGoal {
    var label: String {
        switch self {
        case .lose: L("Giảm")
        case .maintain: L("Duy trì")
        case .gain: L("Tăng")
        }
    }

    /// "−500 kcal" / "±0 kcal" / "+350 kcal".
    @MainActor
    var deltaText: String {
        switch self {
        case .lose: "−\(AppNumber.int(abs(dailyCalorieDelta))) kcal"
        case .maintain: "±0 kcal"
        case .gain: "+\(AppNumber.int(dailyCalorieDelta)) kcal"
        }
    }
}

extension BiologicalSex {
    var label: String {
        switch self {
        case .male: L("Nam")
        case .female: L("Nữ")
        case .preferNotToSay: L("Không nói")
        }
    }
}

extension BMICategory {
    var label: String {
        switch self {
        case .underweight: L("Thiếu cân")
        case .normal: L("Bình thường")
        case .overweight: L("Thừa cân")
        case .obese: L("Béo phì")
        }
    }
}

extension NotificationPreference {
    /// §6.13's table, in its order.
    var label: String {
        switch self {
        case .seventyPercent: L("Khi dùng 70% ngân sách")
        case .nearTarget: L("Khi gần mục tiêu (90%)")
        case .targetReached: L("Khi đạt mục tiêu")
        case .mealReminder: L("Nhắc ghi bữa ăn")
        case .dailySummary: L("Tóm tắt hằng ngày")
        }
    }
}

/// Display names for the gateway's `nutritionSource` strings.
///
/// One place, because the review screen names the source twice — once per item
/// and once for the plate — and a new source that only got taught to one of
/// them would be shown raw in the other.
///
/// The wording distinguishes **how a figure was arrived at**, which is the only
/// thing a reader can act on: a recipe over public-domain rows and an asserted
/// row look identical on screen otherwise.
enum NutritionSourceCopy {
    @MainActor
    static func name(for source: String?) -> String? {
        switch source {
        case "usda_sr_legacy_recipe": L("công thức từ USDA")
        case "usda_fdc": L("USDA FoodData Central")
        case "open_food_facts": L("Open Food Facts")
        case "local_reference": L("dữ liệu tham khảo nội bộ")
        case "user_entered": L("bạn nhập")
        // A source this build has not been taught. Shown raw rather than
        // hidden: an unfamiliar name is a smaller lie than none.
        case let other?: other
        case nil: nil
        }
    }
}

enum BudgetCopy {
    /// The status note from §6.4. `nil` below 70% — nothing worth saying yet.
    ///
    /// `remainingKcal` is the signed remainder; the copy uses its magnitude.
    @MainActor
    static func note(for status: CalorieBudgetStatus, remainingKcal: Double) -> String? {
        let magnitude = AppNumber.int(abs(remainingKcal))
        switch status {
        case .normal:
            return nil
        case .informUser:
            return L("Bạn còn \(magnitude) kcal cho hôm nay.")
        case .nearTarget:
            return L("Bạn đang gần mục tiêu calo hôm nay.")
        case .reached:
            return L("Bạn đã đạt mục tiêu calo hôm nay.")
        case .exceeded:
            return L("Bạn đã vượt mục tiêu hôm nay \(magnitude) kcal.")
        }
    }
}

extension MealType {
    /// Which meal a scan should default to, by time of day. Arbitrary defaults
    /// would make the user re-pick almost every time.
    static func suggestedForNow(_ date: Date = Date()) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<10: .breakfast
        case 10..<15: .lunch
        case 15..<18: .snack
        default: .dinner
        }
    }
}
