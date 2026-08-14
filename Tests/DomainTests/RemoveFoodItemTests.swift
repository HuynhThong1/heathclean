import Domain
import Foundation
import Testing

@Suite("Removing one food from a meal")
struct RemoveFoodItemTests {
    private func meal(items: [FoodItem]) -> Meal {
        Meal(date: referenceDate, type: .lunch, items: items)
    }

    @Test("the other foods survive, and the meal is updated rather than replaced")
    func removesOneItem() async throws {
        let rice = makeFoodItem(name: "Cơm tấm", calories: 300)
        let pork = makeFoodItem(name: "Sườn nướng", calories: 360)
        let stored = meal(items: [rice, pork])
        let repository = InMemoryMealRepository(stored: [stored])
        let useCase = RemoveFoodItemUseCase(mealRepository: repository)

        let outcome = try await useCase.execute(itemID: rice.id, from: stored)

        guard case let .itemRemoved(updated) = outcome else {
            Issue.record("expected .itemRemoved, got \(outcome)")
            return
        }
        #expect(updated.items.map(\.name) == ["Sườn nướng"])
        expectClose(updated.calories, 360)
        // Same meal, not a new one: history would otherwise gain a duplicate.
        #expect(updated.id == stored.id)
        #expect(await repository.count == 1)
        #expect(await repository.all().first?.items.count == 1)
    }

    @Test("removing the last food deletes the meal instead of storing it empty")
    func lastItemDeletesTheMeal() async throws {
        let only = makeFoodItem(name: "Phở bò", calories: 585)
        let stored = meal(items: [only])
        let repository = InMemoryMealRepository(stored: [stored])
        let useCase = RemoveFoodItemUseCase(mealRepository: repository)

        let outcome = try await useCase.execute(itemID: only.id, from: stored)

        // SaveMealUseCase rejects a meal with no items, so deletion must not be
        // able to create one — an empty meal would appear in history as 0 kcal
        // with nothing to explain it.
        #expect(outcome == .mealDeleted(photoIDs: []))
        #expect(await repository.count == 0)
    }

    @Test("deleting the last food reports the photos that went with the meal")
    func lastItemReportsItsPhotos() async throws {
        let only = makeFoodItem(name: "Phở bò", calories: 585)
        let first = MealPhoto(capturedAt: referenceDate, pixelWidth: 1_600, pixelHeight: 1_200)
        let second = MealPhoto(capturedAt: referenceDate, pixelWidth: 1_600, pixelHeight: 900)
        let stored = Meal(
            date: referenceDate,
            type: .lunch,
            items: [only],
            photos: [first, second]
        )
        let repository = InMemoryMealRepository(stored: [stored])
        let useCase = RemoveFoodItemUseCase(mealRepository: repository)

        let outcome = try await useCase.execute(itemID: only.id, from: stored)

        // The ids come back so the App layer can delete the files: the store
        // cascades rows, and nothing else would ever reference those bytes again.
        #expect(outcome == .mealDeleted(photoIDs: [first.id, second.id]))
        #expect(await repository.count == 0)
        #expect(try await repository.photoIDs().isEmpty)
    }

    @Test("an item that is not in the meal is not an error")
    func unknownItemIsNotAnError() async throws {
        let stored = meal(items: [makeFoodItem()])
        let repository = InMemoryMealRepository(stored: [stored])
        let useCase = RemoveFoodItemUseCase(mealRepository: repository)

        let outcome = try await useCase.execute(itemID: UUID(), from: stored)

        #expect(outcome == .notFound)
        #expect(await repository.count == 1)
    }

    @Test("removing does not disturb a different meal on the same day")
    func leavesOtherMealsAlone() async throws {
        let lunchItem = makeFoodItem(name: "Cơm tấm", calories: 300)
        let lunch = meal(items: [lunchItem, makeFoodItem(name: "Trứng ốp la")])
        let dinner = Meal(date: referenceDate, type: .dinner, items: [makeFoodItem()])
        let repository = InMemoryMealRepository(stored: [lunch, dinner])
        let useCase = RemoveFoodItemUseCase(mealRepository: repository)

        try await useCase.execute(itemID: lunchItem.id, from: lunch)

        #expect(await repository.count == 2)
        #expect(await repository.all().first { $0.type == .dinner }?.items.count == 1)
    }
}
