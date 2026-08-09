/// Used by the Mifflin-St Jeor basal metabolic rate formula.
///
/// `preferNotToSay` is a first-class option: the calorie goal engine falls back
/// to the midpoint of the male and female constants rather than refusing to
/// produce a target.
public enum BiologicalSex: String, CaseIterable, Sendable {
    case male
    case female
    case preferNotToSay
}
