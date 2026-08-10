import Domain
import SwiftUI

// Display strings live in Presentation so the Domain stays free of copy.

extension ActivityLevel {
    var title: String {
        switch self {
        case .sedentary: "Sedentary — little or no exercise"
        case .light: "Light — 1–3 days a week"
        case .moderate: "Moderate — 3–5 days a week"
        case .active: "Active — 6–7 days a week"
        case .veryActive: "Very active — physical job or twice daily"
        }
    }
}

extension WeightGoal {
    var title: String {
        switch self {
        case .lose: "Lose"
        case .maintain: "Maintain"
        case .gain: "Gain"
        }
    }
}

extension BMICategory {
    var title: String {
        switch self {
        case .underweight: "Underweight"
        case .normal: "Normal"
        case .overweight: "Overweight"
        case .obese: "Obese"
        }
    }

    var badgeTone: DSBadgeTone {
        switch self {
        case .normal: .green
        case .underweight, .overweight: .orange
        case .obese: .danger
        }
    }
}

extension MealType {
    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .snack: "Snack"
        case .dinner: "Dinner"
        }
    }
}

extension CalorieBudgetStatus {
    /// Neutral, informative colouring — nothing alarming. Maps onto the brand
    /// ramp: green while there is room, the orange accent as the target nears,
    /// the danger red only once it is met or passed.
    var tint: Color {
        switch self {
        case .normal, .informUser: DSColor.success
        case .nearTarget: DSColor.actionAccent
        case .reached, .exceeded: DSColor.danger
        }
    }

    var badgeTone: DSBadgeTone {
        switch self {
        case .normal, .informUser: .green
        case .nearTarget: .orange
        case .reached, .exceeded: .danger
        }
    }

    var statTone: DSStatTone {
        switch self {
        case .normal, .informUser: .blue
        case .nearTarget: .orange
        case .reached, .exceeded: .neutral
        }
    }

    /// The card's top accent bar follows the same progression.
    var accent: DSAccent {
        switch self {
        case .normal, .informUser: .blue
        case .nearTarget: .orange
        case .reached, .exceeded: .orange
        }
    }
}
