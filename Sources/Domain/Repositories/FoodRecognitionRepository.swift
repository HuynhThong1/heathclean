import Foundation

public enum FoodRecognitionError: Error, Equatable, Sendable {
    /// The gateway was reached but the model behind it failed.
    case modelUnavailable
    /// No network, or the gateway itself is down.
    case unreachable
    /// The image was rejected — too large, or not an image.
    case rejected(reason: String)
}

/// Recognizes foods in a meal photo.
///
/// The Domain deliberately does not know which model is behind this
/// (`plan.md` §9). It also never receives calories from a model: whatever
/// implements this must have had nutrition resolved from a database, so
/// swapping providers cannot change the arithmetic.
public protocol FoodRecognitionRepository: Sendable {
    func analyze(image: Data, mimeType: String) async throws -> FoodAnalysisResult
}
