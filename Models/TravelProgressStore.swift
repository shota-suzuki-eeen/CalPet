import Foundation

struct TravelProgressStore {
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    private enum Key {
        static let weekStart = "travel.weekStart"
        static let previousWeeklySteps = "travel.previousWeeklySteps"
        static let processedMilestone = "travel.processedMilestoneIndex"
        static let satisfaction = "travel.satisfaction"
        static let dayKey = "travel.satisfaction.dayKey"
        static let dayBuckets = "travel.satisfaction.dayBuckets"
    }

    func currentISOWeekStart(for date: Date = Date()) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    mutating func resetIfWeekChanged(now: Date = Date(), maxSatisfaction: Int) {
        let currentWeek = currentISOWeekStart(for: now)
        if let saved = defaults.object(forKey: Key.weekStart) as? Date,
           calendar.isDate(saved, inSameDayAs: currentWeek) {
            if defaults.object(forKey: Key.satisfaction) == nil {
                defaults.set(maxSatisfaction, forKey: Key.satisfaction)
            }
            return
        }

        defaults.set(currentWeek, forKey: Key.weekStart)
        defaults.set(0, forKey: Key.previousWeeklySteps)
        defaults.set(0, forKey: Key.processedMilestone)
        defaults.set(maxSatisfaction, forKey: Key.satisfaction)
        defaults.set("", forKey: Key.dayKey)
        defaults.set(0, forKey: Key.dayBuckets)
    }

    var weekStart: Date { (defaults.object(forKey: Key.weekStart) as? Date) ?? currentISOWeekStart() }

    var previousWeeklySteps: Int {
        get { max(0, defaults.integer(forKey: Key.previousWeeklySteps)) }
        set { defaults.set(max(0, newValue), forKey: Key.previousWeeklySteps) }
    }

    var processedMilestoneIndex: Int {
        get { max(0, defaults.integer(forKey: Key.processedMilestone)) }
        set { defaults.set(max(0, newValue), forKey: Key.processedMilestone) }
    }

    var satisfaction: Int {
        get {
            if defaults.object(forKey: Key.satisfaction) == nil { return 10 }
            return max(0, defaults.integer(forKey: Key.satisfaction))
        }
        set { defaults.set(max(0, newValue), forKey: Key.satisfaction) }
    }

    var satisfactionDayKey: String {
        get { defaults.string(forKey: Key.dayKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.dayKey) }
    }

    var processedDayBuckets: Int {
        get { max(0, defaults.integer(forKey: Key.dayBuckets)) }
        set { defaults.set(max(0, newValue), forKey: Key.dayBuckets) }
    }
}
