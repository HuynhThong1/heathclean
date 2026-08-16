import Foundation

/// Number formatting for the language the app is drawn in — "1.886" in
/// Vietnamese, "1,886" in English.
///
/// The handoff (§7) is explicit that this must come from a `NumberFormatter`
/// rather than string concatenation, and that it must not follow the *device*
/// locale. It used to pin `vi_VN` for that second reason, from back when the UI
/// was Vietnamese whatever the phone said. Now that `AppLanguage` exists the
/// rule is sharper and the pinning is wrong: the figures follow the **UI's**
/// language, because "2.378 kcal" read on an English screen is two point three
/// seven eight.
///
/// `@MainActor` because `NumberFormatter` is a non-Sendable class being cached;
/// every caller is a view.
@MainActor
enum AppNumber {
    /// One formatter per language, built on first use. A formatter is expensive
    /// to construct and these run once per figure per render.
    private static var integerFormatters: [ResolvedLanguage: NumberFormatter] = [:]
    private static var oneDecimalFormatters: [ResolvedLanguage: NumberFormatter] = [:]

    private static var language: ResolvedLanguage { AppLanguage.current.resolved }

    private static func integerFormatter() -> NumberFormatter {
        let language = language
        if let cached = integerFormatters[language] { return cached }
        let formatter = NumberFormatter()
        formatter.locale = language.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        integerFormatters[language] = formatter
        return formatter
    }

    private static func oneDecimalFormatter() -> NumberFormatter {
        let language = language
        if let cached = oneDecimalFormatters[language] { return cached }
        let formatter = NumberFormatter()
        formatter.locale = language.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        oneDecimalFormatters[language] = formatter
        return formatter
    }

    /// kcal and grams are shown as rounded integers (§7).
    static func int(_ value: Double) -> String {
        integerFormatter().string(from: NSNumber(value: Int(value.rounded()))) ?? "0"
    }

    static func int(_ value: Int) -> String {
        integerFormatter().string(from: NSNumber(value: value)) ?? "0"
    }

    /// BMI and weight are shown to one decimal (§7).
    static func oneDecimal(_ value: Double) -> String {
        oneDecimalFormatter().string(from: NSNumber(value: value)) ?? "0"
    }

    /// A figure with *up to* that many decimals, trailing zeros dropped — body
    /// weight ("70 kg", not "70,0 kg") and the activity multiplier ("×1,375").
    ///
    /// Separate from `oneDecimal`, which pads to one on purpose so a column of
    /// BMIs lines up. Both were `vi_VN` literals written at four call sites
    /// before this existed.
    static func upTo(fractionDigits: Int, _ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(0...fractionDigits)).locale(language.locale)
        )
    }

    /// A 0…1 fraction as a whole percentage — "31%", the way §6.12 prints it.
    ///
    /// Built from the integer formatter with the sign glued on rather than from
    /// `numberStyle = .percent`, which in `vi_VN` puts a space before the symbol
    /// ("31 %"); the design draws it closed up.
    static func percent(_ fraction: Double) -> String {
        int((fraction * 100).rounded()) + "%"
    }
}
