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
    private static func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "vi_VN")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    /// "Thứ Bảy, 9/8" — weekday then day/month, per §6.4.
    static func headerText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.setLocalizedDateFormatFromTemplate("EEEE d M")
        let text = formatter.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Day of month, zero-padded so a column of dates keeps one width.
    ///
    /// Not `VNNumber`: that exists for figures a grouping separator applies to,
    /// and a day of month is never one.
    static func dayNumber(for date: Date) -> String {
        String(format: "%02d", calendar().component(.day, from: date))
    }

    /// "Th 5" / "CN" — the weekday under a history day card's date (HISTORY_SPEC §4).
    ///
    /// Spelled out further than a bare "T5" because it sits in a 42pt column of
    /// its own and reads less like a code there.
    static func weekdayCompact(for date: Date) -> String {
        let weekday = calendar().component(.weekday, from: date)
        return weekday == 1 ? "CN" : "Th \(weekday)"
    }

    /// "Thứ Năm" — spelled out, for VoiceOver and for the day panel's title.
    static func weekdayFull(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        let text = formatter.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "13/8" — the date on a search result (HISTORY_SPEC §8).
    ///
    /// Zero-padded day, so a column of results keeps one width. Built from
    /// components rather than a formatter for the reason `HistoryCalendar`
    /// records: it runs once per row per render.
    static func dayMonth(for date: Date) -> String {
        let parts = calendar().dateComponents([.day, .month], from: date)
        return String(format: "%02d/%d", parts.day ?? 0, parts.month ?? 0)
    }

    /// "Thứ Năm, 13/8/2026" — the day panel's title (HISTORY_SPEC §8).
    static func fullDayText(for date: Date) -> String {
        let parts = calendar().dateComponents([.day, .month, .year], from: date)
        return "\(weekdayFull(for: date)), \(parts.day ?? 0)/\(parts.month ?? 0)/\(parts.year ?? 0)"
    }

    /// "Thứ Năm 13 tháng 8" — the same day read aloud. §7's day-card label opens
    /// with this, so "13/8" is never spoken as a fraction.
    static func spokenDayText(for date: Date) -> String {
        let parts = calendar().dateComponents([.day, .month], from: date)
        return "\(weekdayFull(for: date)) \(parts.day ?? 0) tháng \(parts.month ?? 0)"
    }

    /// "06:50" — the time column of the day panel's meal list.
    static func time(for date: Date) -> String {
        let parts = calendar().dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// "Tháng 8, 2026" from the numbers a `HistoryMonth` carries, with no date to
    /// format — which is what an *empty* month has (HISTORY_SPEC §6).
    static func monthYearText(year: Int, month: Int) -> String {
        "Tháng \(month), \(year)"
    }

    /// Which month the week on screen sits in — "Tháng 8, 2026", widened when
    /// the week straddles a month or a year boundary.
    static func monthText(from start: Date, to end: Date) -> String {
        let calendar = calendar()
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
