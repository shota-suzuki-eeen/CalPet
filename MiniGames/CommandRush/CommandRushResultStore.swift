import Foundation

struct CommandRushResultStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func bestScoreAllTime() -> Int {
        defaults.integer(forKey: "commandRush.best.all")
    }

    func bestScoreToday(now: Date = Date()) -> Int {
        defaults.integer(forKey: dayKey(for: now))
    }

    mutating func save(score: Int, now: Date = Date()) {
        let allTime = bestScoreAllTime()
        if score > allTime {
            defaults.set(score, forKey: "commandRush.best.all")
        }

        let todayKey = dayKey(for: now)
        let todayBest = defaults.integer(forKey: todayKey)
        if score > todayBest {
            defaults.set(score, forKey: todayKey)
        }
    }

    private func dayKey(for date: Date) -> String {
        "commandRush.best.day.\(AppState.makeDayKey(date))"
    }
}
