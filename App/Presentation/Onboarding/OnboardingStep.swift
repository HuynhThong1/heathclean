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
        case .body: "BƯỚC 1 · VỀ BẠN"
        case .activity: "BƯỚC 2 · VẬN ĐỘNG"
        case .goal: "BƯỚC 3 · MỤC TIÊU"
        case .result: "BƯỚC 4 · KẾT QUẢ"
        }
    }

    var title: String {
        switch self {
        case .body: "Cho chúng tôi biết về bạn"
        case .activity: "Một tuần của bạn thế nào?"
        case .goal: "Bạn muốn điều gì?"
        case .result: "Mục tiêu hằng ngày của bạn"
        }
    }

    var subtitle: String {
        switch self {
        case .body: "Dùng để tính chuyển hóa cơ bản theo công thức Mifflin-St Jeor."
        case .activity: "Mức vận động được nhân với chuyển hóa cơ bản của bạn."
        case .goal: "Mục tiêu quyết định phần calo cộng thêm hoặc bớt đi."
        case .result: "Tính từ tuổi, chiều cao, cân nặng, vận động và mục tiêu."
        }
    }

    var cta: String {
        switch self {
        case .body, .activity: "Tiếp tục"
        case .goal: "Xem mục tiêu"
        case .result: "Kết nối Apple Health"
        }
    }

    var counter: String { "\(rawValue)/\(OnboardingStep.allCases.count)" }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}
