import Foundation

struct CommandRushResultStore {
    private let bestScoreKey = "commandRush.bestScore"
    private let bestTodayPrefix = "commandRush.bestToday."

    private var defaults: UserDefaults { .standard }

    func bestScore() -> Int {
        defaults.integer(forKey: bestScoreKey)
    }

    func bestToday(now: Date = Date()) -> Int {
        defaults.integer(forKey: bestTodayPrefix + Self.dayKey(now))
    }

    @discardableResult
    func save(score: Int, now: Date = Date()) -> CommandRushResult {
        let newBest = max(bestScore(), score)
        defaults.set(newBest, forKey: bestScoreKey)

        let dayKey = bestTodayPrefix + Self.dayKey(now)
        let todayBest = max(defaults.integer(forKey: dayKey), score)
        defaults.set(todayBest, forKey: dayKey)

        return CommandRushResult(score: score, bestScore: newBest, bestToday: todayBest)
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
