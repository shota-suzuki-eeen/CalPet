import Foundation

struct CommandRushEngine {
    enum JudgeResult {
        case success
        case miss
    }

    private var recentKinds: [CommandKind] = []
    private var lastGroup: Int?
    private var rng = SystemRandomNumberGenerator()

    mutating func reset() {
        recentKinds.removeAll()
        lastGroup = nil
    }

    mutating func makeNextCommand(level: Int, now: Date = Date()) -> CurrentCommand {
        let deduped = CommandKind.allCases.filter { !recentKinds.contains($0) }
        let available = deduped.isEmpty ? CommandKind.allCases : deduped

        let balanced: [CommandKind]
        if let lastGroup {
            let anotherGroup = available.filter { $0.group != lastGroup }
            balanced = anotherGroup.isEmpty ? available : anotherGroup
        } else {
            balanced = available
        }

        let picked = balanced.randomElement(using: &rng) ?? .tap

        recentKinds.append(picked)
        if recentKinds.count > 2 {
            recentKinds.removeFirst(recentKinds.count - 2)
        }
        lastGroup = picked.group

        let duration = max(0.5, 1.2 - Double(level - 1) * 0.08)
        return CurrentCommand(kind: picked, issuedAt: now, deadlineAt: now.addingTimeInterval(duration))
    }

    func judge(input: InputEvent, command: CurrentCommand, now: Date = Date()) -> JudgeResult {
        guard now <= command.deadlineAt else { return .miss }
        return input.command == command.kind ? .success : .miss
    }

    func isTimedOut(command: CurrentCommand?, now: Date = Date()) -> Bool {
        guard let command else { return false }
        return now > command.deadlineAt
    }
}
