import Domain
import Foundation

/// Fails every analysis, so the path a failed scan takes can be walked by a test.
///
/// The failure branch is the one part of §6.6–6.9 that nothing could reach: the
/// mock always succeeds, the gateway needs a network and a key, and a scan that
/// fails on a real gateway fails for reasons a test cannot arrange. Since the
/// whole point of that branch is that **the flow survives** — the photo stays on
/// screen and the meal can still be logged by hand — it has to be exercisable,
/// or the claim quietly stops being true.
///
/// Behind the same double launch-argument guard as the history and scan-image
/// fixtures (`-uiTesting` plus `-scanFailureFixture`), so it is unreachable in a
/// real build. `DependencyContainer` is where that guard lives.
struct FailingFoodRecognitionRepository: FoodRecognitionRepository {
    /// Long enough that §6.7's analysing screen is actually seen on the way
    /// through, short enough not to pad every run.
    var delay: Duration = .milliseconds(400)

    /// `unreachable` rather than `rejected`: it is the failure a user hits most
    /// (a phone with no signal), and it is the one whose message says nothing
    /// about the photo — so a test asserting the photo is still usable is not
    /// leaning on copy that happens to mention it.
    func analyze(image: Data, mimeType: String) async throws -> FoodAnalysisResult {
        try? await Task.sleep(for: delay)
        throw FoodRecognitionError.unreachable
    }
}
