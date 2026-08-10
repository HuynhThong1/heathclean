import Foundation

/// Vietnamese number formatting — thousands separated by a period ("1.886").
///
/// The handoff (§7) is explicit that this must come from a `vi_VN`
/// `NumberFormatter` rather than string concatenation, and that it must not
/// follow the device locale: the app's copy is Vietnamese regardless of where
/// the phone is set.
///
/// `@MainActor` because `NumberFormatter` is a non-Sendable class being cached;
/// every caller is a view.
@MainActor
enum VNNumber {
    private static let locale = Locale(identifier: "vi_VN")

    private static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let oneDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    /// kcal and grams are shown as rounded integers (§7).
    static func int(_ value: Double) -> String {
        integer.string(from: NSNumber(value: Int(value.rounded()))) ?? "0"
    }

    static func int(_ value: Int) -> String {
        integer.string(from: NSNumber(value: value)) ?? "0"
    }

    /// BMI and weight are shown to one decimal (§7).
    static func oneDecimal(_ value: Double) -> String {
        oneDecimal.string(from: NSNumber(value: value)) ?? "0,0"
    }
}
