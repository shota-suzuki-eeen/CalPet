import Foundation
import SwiftUI
import UIKit

@MainActor
final class CommandRushViewModel: ObservableObject {
    @Published var phase: CommandRushGamePhase = .ready
    @Published var currentCommand: CurrentCommand?
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var lives: Int = 3
    @Published var level: Int = 1
    @Published var progress: Double = 1
    @Published var didHitCommand: Bool = false
    @Published var didMissCommand: Bool = false
    @Published var didClear: Bool = false
    @Published var showGuide: Bool = false
    @Published var guideKind: CommandKind?

    @Published var soundEnabled: Bool = true
    @Published var hapticsEnabled: Bool = true
    @Published var shakeEnabled: Bool = true

    let clearScore = 20
    let playDuration: TimeInterval = 35

    private(set) var petAssetName: String
    private(set) var petID: String
    @Published private(set) var bestAllTime: Int = 0
    @Published private(set) var bestToday: Int = 0

    private var engine = CommandRushEngine()
    private var audio = CommandRushAudio()
    private var resultStore = CommandRushResultStore()
    private var runTask: Task<Void, Never>?
    private let displayLink = DisplayLinkDriver()
    private var runStartAt: Date?

    init(petID: String, petAssetName: String) {
        self.petID = petID
        self.petAssetName = petAssetName
        loadBestScores()

        displayLink.onFrame = { [weak self] in
            self?.updateProgress()
        }
    }

    func start() {
        runTask?.cancel()
        phase = .playing
        score = 0
        combo = 0
        lives = 3
        level = 1
        progress = 1
        currentCommand = nil
        didClear = false
        runStartAt = Date()
        engine = CommandRushEngine()

        displayLink.start()
        runTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        displayLink.stop()
    }

    func handleInput(_ input: InputEvent) {
        guard phase == .playing, let command = currentCommand else { return }

        if command.kind == input.asCommand {
            score += 1
            combo += 1
            level = engine.level(for: score)
            currentCommand = nil
            progress = 1
            fireSuccessFeedback()
            pulseSuccess()

            if score >= clearScore {
                clearGame()
            }
        } else {
            registerMiss()
        }
    }

    private func runLoop() async {
        while !Task.isCancelled && phase == .playing {
            if let runStartAt, Date().timeIntervalSince(runStartAt) >= playDuration {
                if score >= clearScore {
                    clearGame()
                } else {
                    gameOver()
                }
                break
            }

            let kind = engine.nextCommand(level: level, allowShake: shakeEnabled)
            let now = Date()
            let window = engine.responseWindow(level: level)
            currentCommand = CurrentCommand(id: UUID(), kind: kind, issuedAt: now, deadlineAt: now.addingTimeInterval(window))
            showGuideForFirstCommands(kind)

            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))

            guard !Task.isCancelled, phase == .playing else { break }
            if currentCommand?.kind == kind {
                registerMiss()
            }
            try? await Task.sleep(nanoseconds: 90_000_000)
        }
    }

    private func showGuideForFirstCommands(_ kind: CommandKind) {
        guard score < 3 else { return }
        guideKind = kind
        showGuide = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            showGuide = false
        }
    }

    private func updateProgress() {
        guard phase == .playing, let command = currentCommand else {
            progress = 1
            return
        }
        let total = command.deadlineAt.timeIntervalSince(command.issuedAt)
        guard total > 0 else {
            progress = 0
            return
        }
        let remaining = max(0, command.deadlineAt.timeIntervalSinceNow)
        progress = min(1, max(0, remaining / total))
    }

    private func registerMiss() {
        lives -= 1
        combo = 0
        currentCommand = nil
        progress = 1
        fireFailFeedback()
        pulseMiss()

        if lives <= 0 {
            gameOver()
        }
    }

    private func clearGame() {
        phase = .cleared
        didClear = true
        stop()
        resultStore.save(score: score)
        loadBestScores()
        if soundEnabled { audio.play(.clear) }
        if hapticsEnabled { Haptics.notify(.success) }
    }

    private func gameOver() {
        phase = .gameOver
        stop()
        resultStore.save(score: score)
        loadBestScores()
    }

    private func pulseSuccess() {
        didHitCommand = true
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            didHitCommand = false
        }
    }

    private func pulseMiss() {
        didMissCommand = true
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            didMissCommand = false
        }
    }

    private func fireSuccessFeedback() {
        if soundEnabled { audio.play(.success) }
        if hapticsEnabled { Haptics.tap(style: .light) }
    }

    private func fireFailFeedback() {
        if soundEnabled { audio.play(.fail) }
        if hapticsEnabled { Haptics.notify(.warning) }
    }

    private func loadBestScores() {
        bestAllTime = resultStore.bestScoreAllTime()
        bestToday = resultStore.bestScoreToday()
    }
}
