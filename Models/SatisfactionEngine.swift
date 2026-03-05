import Foundation

struct SatisfactionEngine {
    func applyDailyDecay(todaySteps: Int, preset: TravelBalancePreset, store: inout TravelProgressStore) {
        let dayKey = AppState.makeDayKey(Date())
        if store.satisfactionDayKey != dayKey {
            store.satisfactionDayKey = dayKey
            store.processedDayBuckets = 0
        }

        let bucket = max(0, todaySteps / max(1, preset.satisfactionDecaySteps))
        let delta = max(0, bucket - store.processedDayBuckets)
        guard delta > 0 else { return }

        store.processedDayBuckets = bucket
        store.satisfaction = max(0, store.satisfaction - delta)
    }

    @discardableResult
    func recover(by amount: Int = 2, preset: TravelBalancePreset, store: inout TravelProgressStore) -> Int {
        let next = min(preset.maxSatisfaction, store.satisfaction + amount)
        let gained = next - store.satisfaction
        store.satisfaction = next
        return gained
    }
}
