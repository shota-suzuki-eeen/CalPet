import Foundation

enum TravelBalancePreset: String, CaseIterable, Identifiable {
    case casual
    case standard
    case active

    var id: String { rawValue }

    var title: String {
        switch self {
        case .casual: return "A: カジュアル"
        case .standard: return "B: 標準"
        case .active: return "C: アクティブ"
        }
    }

    var weeklyGoalSteps: Int {
        switch self {
        case .casual: return 35_000
        case .standard: return 50_000
        case .active: return 70_000
        }
    }

    var milestoneBaseSpacing: Int {
        switch self {
        case .casual: return 4_000
        case .standard: return 3_500
        case .active: return 3_000
        }
    }

    var satisfactionDecaySteps: Int {
        switch self {
        case .casual: return 1_500
        case .standard: return 1_000
        case .active: return 800
        }
    }

    var maxSatisfaction: Int { 10 }
}
