import Domain
import Foundation

/// Talks to the HealthClean AI gateway (`POST /v1/meals/analyze`).
///
/// The gateway resolves nutrition before replying, so nothing here computes
/// calories — see `plan.md` §2. Which model runs behind it is the gateway's
/// business; `provider` is echoed back only so a result can be attributed.
struct GatewayFoodRecognitionRepository: FoodRecognitionRepository {
    let baseURL: URL
    /// Overrides the gateway's default model for this client, via
    /// `X-Model-Provider`. `nil` uses whatever the gateway is configured with.
    var providerOverride: String?
    var session: URLSession = .shared

    func analyze(image: Data, mimeType: String) async throws -> FoodAnalysisResult {
        var request = URLRequest(url: baseURL.appending(path: "v1/meals/analyze"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let boundary = "healthclean.\(UUID().uuidString)"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        if let providerOverride {
            request.setValue(providerOverride, forHTTPHeaderField: "X-Model-Provider")
        }
        request.httpBody = Self.multipartBody(
            image: image, mimeType: mimeType, boundary: boundary
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FoodRecognitionError.unreachable
        }

        guard let http = response as? HTTPURLResponse else {
            throw FoodRecognitionError.unreachable
        }

        switch http.statusCode {
        case 200:
            break
        case 502, 503, 504:
            // The gateway is up but the model behind it failed — worth
            // offering a retry, unlike a rejected image.
            throw FoodRecognitionError.modelUnavailable
        default:
            throw FoodRecognitionError.rejected(reason: Self.detail(from: data))
        }

        do {
            return try JSONDecoder().decode(AnalyzeResponse.self, from: data).result
        } catch {
            throw FoodRecognitionError.modelUnavailable
        }
    }

    private static func detail(from data: Data) -> String {
        struct Failure: Decodable { let detail: String }
        return (try? JSONDecoder().decode(Failure.self, from: data))?.detail
            ?? "Không phân tích được ảnh."
    }

    private static func multipartBody(image: Data, mimeType: String, boundary: String) -> Data {
        var body = Data()
        func append(_ text: String) {
            body.append(Data(text.utf8))
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"meal.jpg\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(image)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}

// MARK: - Wire format (plan.md §25)

private struct AnalyzeResponse: Decodable {
    struct Item: Decodable {
        let name: String
        let nameEn: String?
        let weight: Double
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let confidence: Double
        let resolved: Bool
        let nutritionSource: String?
        let nutritionSourceId: String?
        let nutritionSourceURL: String?
        let nutritionIsReference: Bool?
    }

    let items: [Item]
    let provider: String

    var result: FoodAnalysisResult {
        FoodAnalysisResult(
            foods: items.map {
                RecognizedFood(
                    name: $0.name,
                    nameEn: $0.nameEn,
                    weightGrams: $0.weight,
                    calories: $0.calories,
                    protein: $0.protein,
                    carbohydrates: $0.carbs,
                    fat: $0.fat,
                    confidence: $0.confidence,
                    isResolved: $0.resolved,
                    nutritionSource: $0.nutritionSource,
                    nutritionSourceID: $0.nutritionSourceId,
                    nutritionSourceURL: $0.nutritionSourceURL,
                    nutritionIsReference: $0.nutritionIsReference ?? false
                )
            },
            provider: provider
        )
    }
}
