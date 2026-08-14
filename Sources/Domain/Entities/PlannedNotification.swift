import Foundation

/// A notification the app has decided to deliver — *what* and *when*, never the
/// words.
///
/// Copy stays in Presentation for the reason `VietnameseCopy.swift` records: the
/// Domain layer is not changed to fit the UI, and the UI is Vietnamese-primary
/// while `EvaluateCalorieBudgetUseCase`'s own messages are English. A `Kind`
/// carries enough for the App layer to write the sentence.
public struct PlannedNotification: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// The budget crossed a threshold. Carries the status so the copy can
        /// say which one without re-deriving it.
        case budget(CalorieBudgetStatus)
        /// Nothing logged today.
        case mealReminder
        /// The day's figures.
        case dailySummary
    }

    public let kind: Kind
    /// When to fire. `nil` means "as soon as possible".
    public let fireDate: Date?

    public init(kind: Kind, fireDate: Date?) {
        self.kind = kind
        self.fireDate = fireDate
    }
}
