import AudioToolbox
import Foundation

@MainActor
final class CommandRushAudio {
    private let successID: SystemSoundID = 1104
    private let missID: SystemSoundID = 1053
    private let clearID: SystemSoundID = 1025

    func prewarm() {
        AudioServicesPlaySystemSound(successID)
    }

    func playSuccess() {
        AudioServicesPlaySystemSound(successID)
    }

    func playMiss() {
        AudioServicesPlaySystemSound(missID)
    }

    func playClear() {
        AudioServicesPlaySystemSound(clearID)
    }
}
