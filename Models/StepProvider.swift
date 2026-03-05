import Foundation

protocol StepProvider {
    func fetchWeeklyTotal(from weekStart: Date, to now: Date) async -> Int
    func fetchTodayTotal(now: Date) async -> Int
}

struct HealthKitStepProvider: StepProvider {
    let hk: HealthKitManager

    func fetchWeeklyTotal(from weekStart: Date, to now: Date) async -> Int {
        await hk.fetchStepCount(from: weekStart, to: now)
    }

    func fetchTodayTotal(now: Date) async -> Int {
        let start = Calendar.current.startOfDay(for: now)
        return await hk.fetchStepCount(from: start, to: now)
    }
}
