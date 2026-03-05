import Foundation
import SwiftUI
import QuartzCore

@MainActor
final class TravelViewModel: ObservableObject {
    @Published var displayedWeeklySteps: Int = 0
    @Published var latestWeeklySteps: Int = 0
    @Published var deltaSteps: Int = 0
    @Published var isDeltaVisible: Bool = false
    @Published var absorbDeltaIntoTotal: Bool = false
    @Published var progress: Double = 0
    @Published var satisfaction: Int = 10
    @Published var rewards: [FoodCatalog.FoodItem] = []
    @Published var hiddenRewardCount: Int = 0
    @Published var message: String = "歩いて旅を進めよう！"

    private var store = TravelProgressStore()
    private let stepProvider: StepProvider
    private let rewardEngine = RewardEngine()
    private let satisfactionEngine = SatisfactionEngine()

    init(stepProvider: StepProvider) {
        self.stepProvider = stepProvider
    }

    func refresh(appState: AppState, preset: TravelBalancePreset, hapticsEnabled: Bool, reduceMotion: Bool, onProgressAnimate: @escaping (Double, TimeInterval) -> Void, save: () -> Void) async {
        store.resetIfWeekChanged(maxSatisfaction: preset.maxSatisfaction)
        let now = Date()

        async let weekly = stepProvider.fetchWeeklyTotal(from: store.weekStart, to: now)
        async let today = stepProvider.fetchTodayTotal(now: now)

        let weeklySteps = max(0, await weekly)
        let todaySteps = max(0, await today)

        let previous = store.previousWeeklySteps
        deltaSteps = max(0, weeklySteps - previous)
        latestWeeklySteps = weeklySteps

        satisfactionEngine.applyDailyDecay(todaySteps: todaySteps, preset: preset, store: &store)
        satisfaction = min(preset.maxSatisfaction, store.satisfaction)

        let rewardSummary = rewardEngine.grantRewards(
            previousSteps: previous,
            currentSteps: weeklySteps,
            preset: preset,
            weekSeedDate: store.weekStart,
            limit: 3,
            store: &store,
            appState: appState
        )
        rewards = rewardSummary.shown
        hiddenRewardCount = rewardSummary.hiddenCount

        if !rewardSummary.shown.isEmpty || rewardSummary.hiddenCount > 0 {
            save()
        }

        displayedWeeklySteps = previous
        progress = min(1, Double(previous) / Double(max(1, preset.weeklyGoalSteps)))

        if deltaSteps > 0 {
            isDeltaVisible = true
            absorbDeltaIntoTotal = false
            try? await Task.sleep(nanoseconds: reduceMotion ? 120_000_000 : 380_000_000)
            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.55)) {
                absorbDeltaIntoTotal = true
            }
            try? await Task.sleep(nanoseconds: reduceMotion ? 130_000_000 : 560_000_000)
            if hapticsEnabled { Haptics.tap(style: .light) }
            isDeltaVisible = false
        }

        let countDuration = reduceMotion ? 0.4 : min(2.2, max(0.55, Double(deltaSteps) / 8_000.0))
        if hapticsEnabled { Haptics.startRattle(style: .soft, interval: 0.05, intensity: 0.65) }
        await animateCounter(from: displayedWeeklySteps, to: weeklySteps, duration: countDuration)
        if hapticsEnabled { Haptics.stopRattle() }

        let finalProgress = min(1, Double(weeklySteps) / Double(max(1, preset.weeklyGoalSteps)))
        let travelDuration = reduceMotion ? 0.18 : min(6.0, max(0.5, Double(deltaSteps) / 2_500.0))
        onProgressAnimate(finalProgress, travelDuration)
        progress = finalProgress

        store.previousWeeklySteps = weeklySteps
        message = satisfaction == 0 ? "お腹が空いて元気がないみたい。食べ物で回復！" : "今週の旅を進行中"
    }

    func recoverByFood(foodId: String, appState: AppState, preset: TravelBalancePreset, save: () -> Void) {
        guard appState.consumeFood(foodId: foodId, count: 1) else { return }
        _ = satisfactionEngine.recover(by: 2, preset: preset, store: &store)
        satisfaction = store.satisfaction
        message = "ごはんで満足度が回復したよ"
        save()
    }

    private func animateCounter(from: Int, to: Int, duration: TimeInterval) async {
        guard to != from else { return }
        let start = CACurrentMediaTime()
        while true {
            let elapsed = CACurrentMediaTime() - start
            let t = min(1, elapsed / max(0.001, duration))
            displayedWeeklySteps = from + Int(Double(to - from) * t)
            if t >= 1 { break }
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }
}
