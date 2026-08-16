import Domain
import SwiftUI

// How a Domain value is *drawn* — tints, tones, accents. What it is *called*
// lives in `DisplayCopy.swift`.
//
// This file used to also carry an English `title` for `ActivityLevel`,
// `WeightGoal`, `BMICategory` and `MealType`: a second set of names, from before
// the app was bilingual, kept in sync with `VietnameseCopy`'s `en` by hand. Two
// English names for one enum is how they start disagreeing, and with the string
// catalog there is now one. The English wording was not lost — it seeded the
// `en` translations.

extension BMICategory {
    var badgeTone: DSBadgeTone {
        switch self {
        case .normal: .green
        case .underweight, .overweight: .orange
        case .obese: .danger
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
