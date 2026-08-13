import Domain
import SwiftUI

/// `MealDetailView` with its model owned by the pushed screen rather than by the
/// closure that pushed it.
///
/// **This exists because of a bug that could not be worked around at the call
/// site.** Every caller used to build the model inline:
///
/// ```swift
/// .navigationDestination(item: $route) { type in
///     MealDetailView(model: container.makeMealDetailModel(type: type, …), …)
/// }
/// ```
///
/// A `navigationDestination` closure is re-evaluated whenever the view that owns
/// it re-renders, so that line hands the pushed screen a **brand-new model** each
/// time — and a new model has `isConfirmingDelete == false`. Tapping the trash on
/// a meal reached from the history day sheet showed the confirmation and lost it
/// in the same instant, because something upstream was re-rendering; the meal
/// could not be deleted at all. The dashboard's copy of the same code happened not
/// to re-render at that moment, which is why it worked and this did not.
///
/// A screen's state must not depend on how often its parent redraws. `@State`
/// here makes the model per-push: created once, kept until the screen goes.
struct MealDetailRoute: View {
    let type: MealType
    let meals: [Meal]
    let dailyGoalCalories: Double
    let onAddMore: () -> Void
    let onChanged: () -> Void
    let onDeleted: () -> Void

    @Environment(DependencyContainer.self) private var container
    @State private var model: MealDetailModel?

    var body: some View {
        Group {
            if let model {
                MealDetailView(
                    model: model,
                    onAddMore: onAddMore,
                    onChanged: onChanged,
                    onDeleted: onDeleted
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.surfacePage)
            }
        }
        // Built here rather than in an initializer so it happens once per push.
        // The meals are the ones that were on screen when the row was tapped;
        // refreshing them is `onChanged`'s job, and the model updates itself in
        // place when an item is removed.
        .task {
            if model == nil {
                model = container.makeMealDetailModel(
                    type: type,
                    meals: meals,
                    dailyGoalCalories: dailyGoalCalories
                )
            }
        }
    }
}
