import Foundation

struct CommandRushEngine {
    private(set) var recentCommands: [CommandKind] = []
    private var random = SystemRandomNumberGenerator()

    mutating func nextCommand(level: Int, allowShake: Bool) -> CommandKind {
        let pool = weightedPool(level: level, allowShake: allowShake)
        var pick = pool.randomElement(using: &random) ?? .tap
        var retryCount = 0

        while recentCommands.suffix(2).contains(pick) && retryCount < 8 {
            pick = pool.randomElement(using: &random) ?? .tap
            retryCount += 1
        }

        recentCommands.append(pick)
        if recentCommands.count > 6 {
            recentCommands.removeFirst(recentCommands.count - 6)
        }
        return pick
    }

    func responseWindow(level: Int) -> TimeInterval {
        max(0.55, 1.15 - Double(level - 1) * 0.06)
    }

    func level(for score: Int) -> Int {
        min(8, max(1, 1 + score / 5))
    }

    private func weightedPool(level: Int, allowShake: Bool) -> [CommandKind] {
        var pool: [CommandKind] = [
            .tap, .tap, .tap,
            .swipeUp, .swipeDown, .swipeLeft, .swipeRight,
            .longPress, .longPress
        ]

        if level >= 3 {
            pool.append(contentsOf: [.pinchIn, .pinchOut])
        }

        if level >= 5 {
            pool.append(contentsOf: [.pinchIn, .pinchOut])
        }

        if allowShake && level >= 4 {
            let shakeWeight = level >= 7 ? 2 : 1
            pool.append(contentsOf: Array(repeating: .shake, count: shakeWeight))
        }

        return pool
    }
}
