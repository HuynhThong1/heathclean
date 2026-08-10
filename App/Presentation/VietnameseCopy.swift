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

    var chipSymbol: String {
        switch self {
        case .breakfast: "sun.horizon"
        case .lunch: "sun.max"
        case .snack: "leaf"
        case .dinner: "moon.stars"
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
            return "Bạn còn \(magnitude) kcal cho hôm nay."
        case .nearTarget:
            return "Bạn đang gần mục tiêu calo hôm nay."
        case .reached:
            return "Bạn đã đạt mục tiêu calo hôm nay."
        case .exceeded:
            return "Bạn đã vượt mục tiêu hôm nay \(magnitude) kcal."
        }
    }
}

enum VietnameseDate {
    /// "Thứ Bảy, 9/8" — weekday then day/month, per §6.4.
    static func headerText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.setLocalizedDateFormatFromTemplate("EEEE d M")
        let text = formatter.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
