import Domain
import Foundation
import Testing

@Suite("Recording weight")
struct RecordWeightTests {
    @Test("the first weighing is always recorded")
    func firstWeighing() async throws {
        let repository = InMemoryWeightRepository()
        let useCase = RecordWeightUseCase(weightRepository: repository)

        let recorded = try await useCase.execute(kilograms: 78.5, on: referenceDate)

        #expect(recorded)
        #expect(await repository.count == 1)
    }

    @Test("an unchanged weight is not recorded again")
    func unchangedWeightIsSkipped() async throws {
        let repository = InMemoryWeightRepository(stored: [
            WeightEntry(date: daysBeforeReference(3), kilograms: 78.5)
        ])
        let useCase = RecordWeightUseCase(weightRepository: repository)

        // Editing activity level re-saves the profile with the same weight.
        let recorded = try await useCase.execute(kilograms: 78.5, on: referenceDate)

        #expect(!recorded)
        #expect(await repository.count == 1)
    }

    @Test("a changed weight is appended, leaving the earlier one in place")
    func changedWeightIsAppended() async throws {
        let repository = InMemoryWeightRepository(stored: [
            WeightEntry(date: daysBeforeReference(7), kilograms: 79.4)
        ])
        let useCase = RecordWeightUseCase(weightRepository: repository)

        let recorded = try await useCase.execute(kilograms: 78.5, on: referenceDate)

        #expect(recorded)
        #expect(await repository.count == 2)
        expectClose(try await repository.latest()?.kilograms ?? 0, 78.5)
    }

    @Test("the comparison is against the most recent weighing, not the oldest")
    func comparesAgainstMostRecent() async throws {
        let repository = InMemoryWeightRepository(stored: [
            WeightEntry(date: daysBeforeReference(14), kilograms: 78.5),
            WeightEntry(date: daysBeforeReference(7), kilograms: 80),
        ])
        let useCase = RecordWeightUseCase(weightRepository: repository)

        // Back to a weight held two weeks ago — that is a real change from 80.
        let recorded = try await useCase.execute(kilograms: 78.5, on: referenceDate)

        #expect(recorded)
        #expect(await repository.count == 3)
    }
}
