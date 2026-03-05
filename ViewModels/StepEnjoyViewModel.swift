import Foundation

@MainActor
final class StepEnjoyViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isClaiming = false

    @Published var deltaSteps: Int = 0
    @Published var dayTotalSteps: Int = 0
    @Published var weekTotalSteps: Int = 0
    @Published var claimableCount: Int = 0

    @Published var gainedFoodName: String?

    func refresh(state: AppState, hk: HealthKitManager, save: () -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        applyDailyResetIfNeeded(state: state, now: now)

        let start = state.stepEnjoyLastCheckedAt ?? now
        let fetchedDelta = await hk.fetchStepCount(from: start, to: now)
        let safeDelta = max(0, fetchedDelta)

        state.stepEnjoyLastCheckedAt = now
        state.stepEnjoyLastDeltaSteps = safeDelta
        state.stepEnjoyTotalSteps += safeDelta
        state.stepEnjoyDailyRewardStepBank += safeDelta

        deltaSteps = safeDelta
        dayTotalSteps = await hk.fetchTodayStepTotal(now: now)
        weekTotalSteps = await hk.fetchWeekStepTotal(now: now)

        claimableCount = StepEnjoyRewardPolicy.claimableCount(
            bank: state.stepEnjoyDailyRewardStepBank,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        save()
    }

    func claimReward(state: AppState, save: () -> Void) {
        guard !isClaiming else { return }
        isClaiming = true
        defer { isClaiming = false }

        let claimable = StepEnjoyRewardPolicy.claimableCount(
            bank: state.stepEnjoyDailyRewardStepBank,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        guard claimable >= 1 else { return }

        state.stepEnjoyDailyRewardStepBank -= StepEnjoyRewardPolicy.rewardStepThreshold
        state.stepEnjoyDailyRewardCount += 1
        state.stepEnjoyLastRewardAt = Date()

        if let reward = FoodCatalog.all.randomElement() {
            _ = state.addFood(foodId: reward.id, count: 1)
            gainedFoodName = reward.name
        } else {
            gainedFoodName = nil
        }

        _ = state.decreaseSatisfaction(by: 1, now: Date())

        claimableCount = StepEnjoyRewardPolicy.claimableCount(
            bank: state.stepEnjoyDailyRewardStepBank,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        save()
    }

    private func applyDailyResetIfNeeded(state: AppState, now: Date) {
        if StepEnjoyRewardPolicy.shouldResetDailyCycle(stored: state.stepEnjoyDailyCycleStart, now: now) {
            state.stepEnjoyDailyCycleStart = StepEnjoyRewardPolicy.normalizedCycleStart(for: now)
            state.stepEnjoyDailyRewardCount = 0
            state.stepEnjoyDailyRewardStepBank = 0
        }
    }
}
