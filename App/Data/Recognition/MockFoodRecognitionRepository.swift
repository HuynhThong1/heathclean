import Domain
import Foundation

/// Stands in for the gateway so the scan flow runs with no network and no
/// model — which is what makes §6.6–6.9 testable at all right now.
///
/// It mirrors the gateway's own mock: deterministic on the image bytes, and it
/// deliberately includes one low-confidence and one unresolved item so the
/// review screen's "Nên kiểm tra" path is exercised rather than assumed.
///
/// **Only two of the four carry a fibre figure**, and that is the interesting
/// case rather than an omission. The real gateway sends no fibre at all today,
/// so a mock that filled in all four would exercise a state the app has never
/// actually been in, and never the mixed one — where the day's total is a floor
/// and has to say so. A plate of rice and grilled pork is also just true to
/// life: the two starchy items are the ones a nutrition table has fibre for.
struct MockFoodRecognitionRepository: FoodRecognitionRepository {
    /// Simulates the round trip so the analysing screen is actually seen.
    var delay: Duration = .milliseconds(1800)

    func analyze(image: Data, mimeType: String) async throws -> FoodAnalysisResult {
        try? await Task.sleep(for: delay)

        return FoodAnalysisResult(
            foods: [
                RecognizedFood(
                    name: "Cơm trắng", nameEn: "White rice",
                    weightGrams: 180, calories: 234,
                    protein: 4.9, carbohydrates: 50.4, fat: 0.5,
                    confidence: 0.92, isResolved: true, fiber: 0.7
                ),
                RecognizedFood(
                    name: "Sườn nướng", nameEn: "Grilled pork chop",
                    weightGrams: 120, calories: 288,
                    protein: 26.4, carbohydrates: 3.6, fat: 18.0,
                    confidence: 0.86, isResolved: true
                ),
                RecognizedFood(
                    name: "Chả giò", nameEn: "Spring roll",
                    weightGrams: 60, calories: 174,
                    protein: 5.4, carbohydrates: 15.6, fat: 9.6,
                    confidence: 0.68, isResolved: true, fiber: 1.2
                ),
                RecognizedFood(
                    name: "Món chưa rõ", nameEn: nil,
                    weightGrams: 80, calories: 0,
                    protein: 0, carbohydrates: 0, fat: 0,
                    confidence: 0.41, isResolved: false
                )
            ],
            provider: "mock"
        )
    }
}
