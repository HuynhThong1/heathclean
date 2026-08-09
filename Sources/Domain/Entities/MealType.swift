public enum MealType: String, CaseIterable, Sendable, Identifiable {
    case breakfast
    case lunch
    case snack
    case dinner

    public var id: String { rawValue }
}
