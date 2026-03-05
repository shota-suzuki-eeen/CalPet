import Foundation

enum StepEnjoyRewardPolicy {
    static let rewardStepThreshold = 2_000
    static let dailyRewardMaxCount = 5
    static let dailyRewardStepCap = 10_000

    static func todayCycleStart(now: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    static func needsDailyReset(cycleStart: Date, now: Date, calendar: Calendar = .current) -> Bool {
        !calendar.isDate(cycleStart, inSameDayAs: now)
    }

    static func claimableCount(bank: Int, dailyRewardCount: Int) -> Int {
        let eligibleBySteps = max(0, bank / rewardStepThreshold)
        let eligibleByCap = max(0, dailyRewardMaxCount - dailyRewardCount)
        return max(0, min(eligibleBySteps, eligibleByCap))
    }

    static func stepsUntilNextReward(bank: Int) -> Int {
        let remainder = max(0, bank) % rewardStepThreshold
        if remainder == 0 { return rewardStepThreshold }
        return rewardStepThreshold - remainder
    }
}
