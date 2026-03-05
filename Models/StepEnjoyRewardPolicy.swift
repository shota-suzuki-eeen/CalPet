import Foundation

enum StepEnjoyRewardPolicy {
    static let rewardStepThreshold = 2_000
    static let dailyRewardMaxCount = 5
    static let dailyRewardStepCap = 10_000

    static func normalizedCycleStart(for now: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    static func shouldResetDailyCycle(stored: Date, now: Date, calendar: Calendar = .current) -> Bool {
        normalizedCycleStart(for: stored, calendar: calendar) != normalizedCycleStart(for: now, calendar: calendar)
    }

    static func claimableCount(bank: Int, claimedToday: Int) -> Int {
        let eligibleBySteps = max(0, bank / rewardStepThreshold)
        let eligibleByCap = max(0, dailyRewardMaxCount - claimedToday)
        return max(0, min(eligibleBySteps, eligibleByCap))
    }

    static func nextRewardRemainingSteps(bank: Int, claimedToday: Int) -> Int {
        guard claimedToday < dailyRewardMaxCount else { return 0 }
        let mod = max(0, bank % rewardStepThreshold)
        return mod == 0 ? rewardStepThreshold : (rewardStepThreshold - mod)
    }
}
