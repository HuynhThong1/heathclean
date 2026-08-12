import Domain
import SwiftUI

/// Vietnamese-primary copy with English sub-labels (handoff §4).
///
/// All of it lives in Presentation. `EvaluateCalorieBudgetUseCase` already
/// carries English message strings, but the Domain layer is not to be changed to
/// fit the UI — so the views map the *status* to Vietnamese here and leave the
/// Domain's own copy alone.
extension MealType {
    var vi: String {
        switch self {
        case .breakfast: "Bữa sáng"
        case .lunch: "Bữa trưa"
        case .snack: "Bữa phụ"
        case .dinner: "Bữa tối"
        }
    }

    var en: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .snack: "Snack"
        case .dinner: "Dinner"
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
    var vi: String {
        switch self {
        case .sedentary: "Ít vận động"
        case .light: "Nhẹ — 1–3 ngày/tuần"
        case .moderate: "Trung bình — 3–5 ngày/tuần"
        case .active: "Tích cực — 6–7 ngày/tuần"
        case .veryActive: "Rất tích cực — việc thể lực"
        }
    }

    var en: String {
        switch self {
        case .sedentary: "Almost no exercise"
        case .light: "Light"
        case .moderate: "Moderate"
        case .active: "Active"
        case .veryActive: "Very active"
        }
    }

    /// "×1,375" — the multiplier as shown on the activity cards (§6.2 step 2).
    var multiplierText: String {
        "×" + multiplier.formatted(
            .number.precision(.fractionLength(0...3)).locale(Locale(identifier: "vi_VN"))
        )
    }
}

extension WeightGoal {
    var vi: String {
        switch self {
        case .lose: "Giảm"
        case .maintain: "Duy trì"
        case .gain: "Tăng"
        }
    }

    /// "−500 kcal" / "±0 kcal" / "+350 kcal".
    @MainActor
    var deltaText: String {
        switch self {
        case .lose: "−\(VNNumber.int(abs(dailyCalorieDelta))) kcal"
        case .maintain: "±0 kcal"
        case .gain: "+\(VNNumber.int(dailyCalorieDelta)) kcal"
        }
    }
}

extension BiologicalSex {
    var vi: String {
        switch self {
        case .male: "Nam"
        case .female: "Nữ"
        case .preferNotToSay: "Không nói"
        }
    }
}

extension BMICategory {
    var vi: String {
        switch self {
        case .underweight: "Thiếu cân"
        case .normal: "Bình thường"
        case .overweight: "Thừa cân"
        case .obese: "Béo phì"
        }
    }

    var en: String {
        switch self {
        case .underweight: "Underweight"
        case .normal: "Normal"
        case .overweight: "Overweight"
        case .obese: "Obese"
        }
    }
}

enum BudgetCopy {
    /// The status note from §6.4. `nil` below 70% — nothing worth saying yet.
    ///
    /// `remainingKcal` is the signed remainder; the copy uses its magnitude.
    @MainActor
    static func note(for status: CalorieBudgetStatus, remainingKcal: Double) -> String? {
        let magnitude = VNNumber.int(abs(remainingKcal))
        switch status {
        case .normal:
            return nil
        case .informUser:
            return String(localized: "Bạn còn \(magnitude) kcal cho hôm nay.")
        case .nearTarget:
            return String(localized: "Bạn đang gần mục tiêu calo hôm nay.")
        case .reached:
            return String(localized: "Bạn đã đạt mục tiêu calo hôm nay.")
        case .exceeded:
            return String(localized: "Bạn đã vượt mục tiêu hôm nay \(magnitude) kcal.")
        }
    }
}

enum VietnameseDate {
    /// "Thứ Sáu 8/8" — weekday then day/month, used by history sections.
    static func dayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.setLocalizedDateFormatFromTemplate("EEEE d M")
        let text = formatter.string(from: date).replacingOccurrences(of: ",", with: "")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "Thứ Bảy, 9/8" — weekday then day/month, per §6.4.
    static func headerText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.setLocalizedDateFormatFromTemplate("EEEE d M")
        let text = formatter.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "T2"…"CN" — the weekday label on the history week strip.
    ///
    /// `InsightsView` carries its own copy for the bar chart, which also says
    /// "Nay" for today. The strip does not: its seven columns are a fixed grid
    /// and a wider label on one of them makes the row shift as weeks change.
    static func weekdayShort(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 ? "CN" : "T\(weekday)"
    }

    /// Day of month, zero-padded so the seven columns keep one width.
    ///
    /// Not `VNNumber`: that exists for figures a grouping separator applies to,
    /// and a day of month is never one.
    static func dayNumber(for date: Date) -> String {
        String(format: "%02d", Calendar.current.component(.day, from: date))
    }

    /// Which month the week on screen sits in — "Tháng 8, 2026", widened when
    /// the week straddles a month or a year boundary.
    static func monthText(from start: Date, to end: Date) -> String {
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)

        if startYear != endYear {
            return "Tháng \(startMonth), \(startYear) – tháng \(endMonth), \(endYear)"
        }
        if startMonth != endMonth {
            return "Tháng \(startMonth) – \(endMonth), \(startYear)"
        }
        return "Tháng \(startMonth), \(startYear)"
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
