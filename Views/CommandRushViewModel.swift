import Foundation
import SwiftUI

@MainActor
final class CommandRushViewModel: ObservableObject {
    @Published private(set) var phase: GamePhase = .ready
    @Published private(set) var score: Int = 0
    @Published private(set) var combo: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var lives: Int = 3
    @Published private(set) var currentCommand: CurrentCommand?
    @Published private(set) var progress: CGFloat = 1
    @Published private(set) var danceTransform: DanceTransform = .neutral
    @Published private(set) var flashColor: Color = .clear
    @Published private(set) var showGhostGuide: Bool = false
    @Published private(set) var ghostGuideKind: CommandKind = .tap
    @Published private(set) var result: CommandRushResult?

    @Published var soundEnabled = true
    @Published var hapticsEnabled = true

    private var engine = CommandRushEngine()
    private let audio = CommandRushAudio()
    private let resultStore = CommandRushResultStore()
    private let displayLink = DisplayLinkDriver()

    private var commandTask: Task<Void, Never>?
    private var startedAt: Date?
    private var ghostCount = 0
    private var reduceMotion = false

    let targetScore = 20

    init() {
        displayLink.onFrame = { [weak self] _ in
            self?.updateProgressFrame()
        }
    }

    func configure(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
    }

    func startGame() {
        commandTask?.cancel()
        engine.reset()
        score = 0
        combo = 0
        level = 1
        lives = 3
        progress = 1
        phase = .playing
        result = nil
        ghostCount = 0
        startedAt = Date()
        displayLink.start()
        audio.prewarm()
        scheduleNextCommand(after: 0.6)
    }

    func stopGame() {
        commandTask?.cancel()
        displayLink.stop()
    }

    func handleTap() {
        guard phase == .playing, let command = currentCommand else { return }
        handleInput(.tap, command: command)
    }

    func handleSwipe(_ direction: CommandKind) {
        guard phase == .playing, let command = currentCommand else { return }
        handleInput(.swipe(direction), command: command)
    }

    func bestScoreText() -> String {
        "BEST \(resultStore.bestScore()) / TODAY \(resultStore.bestToday())"
    }

    private func handleInput(_ input: InputEvent, command: CurrentCommand) {
        currentCommand = nil
        switch engine.judge(input: input, command: command) {
        case .success:
            score += 1
            combo += 1
            level = min(8, 1 + score / 4)
            applyDance(command.kind, success: true)
            emitSuccessEffects()
            evaluateFinishIfNeeded()
            if phase == .playing { scheduleNextCommand(after: 0.1) }

        case .miss:
            onMiss()
        }
    }

    private func onMiss() {
        currentCommand = nil
        lives -= 1
        combo = 0
        flashColor = .red.opacity(0.35)
        withAnimation(.easeOut(duration: 0.18)) {
            danceTransform = reduceMotion ? .neutral : DanceTransform(offset: .zero, scale: 0.94, rotation: 0, opacity: 0.9)
        }
        withAnimation(.easeOut(duration: 0.25)) {
            flashColor = .clear
        }
        if soundEnabled { audio.playMiss() }
        if hapticsEnabled { Haptics.notify(.warning) }

        if lives <= 0 {
            endGame(cleared: false)
        } else {
            scheduleNextCommand(after: 0.2)
        }
    }

    private func applyDance(_ kind: CommandKind, success: Bool) {
        let amp: CGFloat = success ? (1 + min(CGFloat(combo), 12) * 0.02) : 1
        withAnimation(.spring(response: 0.18, dampingFraction: 0.58)) {
            danceTransform = reduceMotion ? .neutral : .forCommand(kind, amplify: amp)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            withAnimation(.easeOut(duration: 0.16)) {
                self.danceTransform = .neutral
            }
        }
    }

    private func emitSuccessEffects() {
        flashColor = .green.opacity(0.2)
        withAnimation(.easeOut(duration: 0.16)) {
            flashColor = .clear
        }
        if soundEnabled { audio.playSuccess() }
        if hapticsEnabled { Haptics.tap(style: .light) }
    }

    private func scheduleNextCommand(after delay: TimeInterval) {
        commandTask?.cancel()
        commandTask = Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled, phase == .playing else { return }
            let next = engine.makeNextCommand(level: level)
            currentCommand = next
            progress = 1
            maybeShowGhostGuide(for: next.kind)
        }
    }

    private func updateProgressFrame() {
        guard phase == .playing, let command = currentCommand else { return }

        let now = Date()
        let total = command.deadlineAt.timeIntervalSince(command.issuedAt)
        let left = command.deadlineAt.timeIntervalSince(now)
        progress = CGFloat(max(0, min(1, left / max(total, 0.01))))

        if engine.isTimedOut(command: command, now: now) {
            onMiss()
        }

        if let startedAt, now.timeIntervalSince(startedAt) >= 35, score < targetScore {
            endGame(cleared: false)
        }
    }

    private func maybeShowGhostGuide(for kind: CommandKind) {
        guard ghostCount < 4 else { return }
        ghostCount += 1
        ghostGuideKind = kind
        showGhostGuide = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                self.showGhostGuide = false
            }
        }
    }

    private func evaluateFinishIfNeeded() {
        if score >= targetScore {
            endGame(cleared: true)
        }
    }

    private func endGame(cleared: Bool) {
        commandTask?.cancel()
        displayLink.stop()
        currentCommand = nil
        phase = cleared ? .cleared : .gameOver
        result = resultStore.save(score: score)

        if cleared {
            if soundEnabled { audio.playClear() }
            if hapticsEnabled { Haptics.notify(.success) }
        } else if hapticsEnabled {
            Haptics.notify(.error)
        }
    }
}
