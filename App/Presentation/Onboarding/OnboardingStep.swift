import Foundation

/// The four onboarding steps and their copy, from handoff §6.2.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case body = 1
    case activity
    case goal
    case result

    var id: Int { rawValue }

    var eyebrow: String {
        switch self {
        case .body: L("BƯỚC 1 · VỀ BẠN")
        case .activity: L("BƯỚC 2 · VẬN ĐỘNG")
        case .goal: L("BƯỚC 3 · MỤC TIÊU")
        case .result: L("BƯỚC 4 · KẾT QUẢ")
        }
    }

    var title: String {
        switch self {
        case .body: L("Cho chúng tôi biết về bạn")
        case .activity: L("Một tuần của bạn thế nào?")
        case .goal: L("Bạn muốn điều gì?")
        case .result: L("Mục tiêu hằng ngày của bạn")
        }
    }

    var subtitle: String {
        switch self {
        case .body: L("Dùng để tính chuyển hóa cơ bản theo công thức Mifflin-St Jeor.")
        case .activity: L("Mức vận động được nhân với chuyển hóa cơ bản của bạn.")
        case .goal: L("Mục tiêu quyết định phần calo cộng thêm hoặc bớt đi.")
        case .result: L("Tính từ tuổi, chiều cao, cân nặng, vận động và mục tiêu.")
        }
    }

    var cta: String {
        switch self {
        case .body, .activity: L("Tiếp tục")
        case .goal: L("Xem mục tiêu")
        case .result: L("Kết nối Apple Health")
        }
    }

    var counter: String { "\(rawValue)/\(OnboardingStep.allCases.count)" }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}
