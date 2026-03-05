import Foundation
import GameplayKit

struct TravelRewardSummary {
    let shown: [FoodCatalog.FoodItem]
    let hiddenCount: Int
}

struct RewardEngine {
    func grantRewards(
        previousSteps: Int,
        currentSteps: Int,
        preset: TravelBalancePreset,
        weekSeedDate: Date,
        limit: Int,
        store: inout TravelProgressStore,
        appState: AppState
    ) -> TravelRewardSummary {
        let milestones = makeMilestones(preset: preset, weekSeedDate: weekSeedDate)
        var nextIndex = store.processedMilestoneIndex
        var granted: [FoodCatalog.FoodItem] = []

        while nextIndex < milestones.count, currentSteps >= milestones[nextIndex] {
            let seed = UInt64(weekSeedDate.timeIntervalSince1970) ^ UInt64(nextIndex * 7919)
            let rng = GKMersenneTwisterRandomSource(seed: seed)
            let idx = rng.nextInt(upperBound: FoodCatalog.all.count)
            let food = FoodCatalog.all[idx]
            if appState.addFood(foodId: food.id, count: 1) {
                granted.append(food)
            }
            nextIndex += 1
        }

        if nextIndex > store.processedMilestoneIndex {
            store.processedMilestoneIndex = nextIndex
        }

        return TravelRewardSummary(
            shown: Array(granted.prefix(limit)),
            hiddenCount: max(0, granted.count - limit)
        )
    }

    private func makeMilestones(preset: TravelBalancePreset, weekSeedDate: Date) -> [Int] {
        var result: [Int] = []
        var step = preset.milestoneBaseSpacing
        let jitter = max(120, Int(Double(step) * 0.08))
        let rng = GKMersenneTwisterRandomSource(seed: UInt64(weekSeedDate.timeIntervalSince1970))

        while step <= preset.weeklyGoalSteps {
            result.append(step)
            let offset = rng.nextInt(upperBound: jitter * 2 + 1) - jitter
            step += max(1_200, preset.milestoneBaseSpacing + offset)
        }
        return result
    }
}
