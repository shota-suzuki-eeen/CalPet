import Foundation

struct StepEnjoyLog: Codable, Identifiable, Equatable {
    let date: Date
    let delta: Int
    let totalAfter: Int
    let dayTotal: Int
    let weekTotal: Int
    let rewardsGranted: Int
    let satDelta: Int

    var id: Date { date }
}

extension AppState {
    func stepEnjoyLogs() -> [StepEnjoyLog] {
        guard let data = stepEnjoyLogsData,
              let logs = try? JSONDecoder().decode([StepEnjoyLog].self, from: data) else {
            return []
        }
        return logs
    }

    func setStepEnjoyLogs(_ logs: [StepEnjoyLog]) {
        stepEnjoyLogsData = try? JSONEncoder().encode(logs)
    }
}
