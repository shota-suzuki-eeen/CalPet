import Foundation

@MainActor
final class StepEnjoyViewModel: ObservableObject {
    @Published private(set) var dayTotalSteps: Int = 0
    @Published private(set) var weekTotalSteps: Int = 0
    @Published private(set) var claimableCount: Int = 0
    @Published private(set) var lastGrantedFood: FoodCatalog.FoodItem?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isClaiming: Bool = false

    func refresh(state: AppState, hk: HealthKitManager, save: () -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let cycleStart = StepEnjoyRewardPolicy.todayCycleStart(now: now)
        if StepEnjoyRewardPolicy.needsDailyReset(cycleStart: state.stepEnjoyDailyCycleStart, now: now) {
            state.stepEnjoyDailyCycleStart = cycleStart
            state.stepEnjoyDailyRewardCount = 0
            state.stepEnjoyDailyRewardStepBank = 0
        }

        let start = state.stepEnjoyLastCheckedAt ?? now
        var deltaSteps = await hk.fetchStepCount(from: start, to: now)
        deltaSteps = max(0, deltaSteps)

        state.stepEnjoyLastCheckedAt = now
        state.stepEnjoyLastDeltaSteps = deltaSteps
        state.stepEnjoyTotalSteps += deltaSteps

        async let day = hk.fetchTodayStepTotal(now: now)
        async let week = hk.fetchWeekStepTotal(now: now)
        dayTotalSteps = await day
        weekTotalSteps = await week

        state.stepEnjoyDailyRewardStepBank += deltaSteps
        claimableCount = StepEnjoyRewardPolicy.claimableCount(
            bank: state.stepEnjoyDailyRewardStepBank,
            dailyRewardCount: state.stepEnjoyDailyRewardCount
        )

        save()
    }

    func claimReward(state: AppState, save: () -> Void) {
        guard !isClaiming else { return }
        guard claimableCount >= 1 else { return }
        guard !FoodCatalog.all.isEmpty else { return }

        isClaiming = true
        defer { isClaiming = false }

        state.stepEnjoyDailyRewardStepBank -= StepEnjoyRewardPolicy.rewardStepThreshold
        state.stepEnjoyDailyRewardCount += 1
        state.stepEnjoyLastRewardAt = Date()

        if let reward = FoodCatalog.all.randomElement() {
            _ = state.addFood(foodId: reward.id, count: 1)
            lastGrantedFood = reward
        }

        _ = state.reduceSatisfactionByOne(now: Date())

        claimableCount = StepEnjoyRewardPolicy.claimableCount(
            bank: state.stepEnjoyDailyRewardStepBank,
            dailyRewardCount: state.stepEnjoyDailyRewardCount
        )
        save()
    }

    func loadCached(state: AppState) {
        claimableCount = StepEnjoyRewardPolicy.claimableCount(
            bank: state.stepEnjoyDailyRewardStepBank,
            dailyRewardCount: state.stepEnjoyDailyRewardCount
        )
    }

    func resetProgress(state: AppState, now: Date = Date(), save: () -> Void) {
        state.stepEnjoyLastCheckedAt = now
        state.stepEnjoyTotalSteps = 0
        state.stepEnjoyLastDeltaSteps = 0
        save()
    }
}
