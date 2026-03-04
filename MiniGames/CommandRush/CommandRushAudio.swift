import Foundation
import AVFoundation
import AudioToolbox

enum CommandRushSound {
    case success
    case fail
    case clear
}

final class CommandRushAudio {
    private var players: [CommandRushSound: AVAudioPlayer] = [:]

    init() {
        players[.success] = makePlayer(name: "success", ext: "wav")
        players[.fail] = makePlayer(name: "fail", ext: "wav")
        players[.clear] = makePlayer(name: "clear", ext: "wav")
    }

    func play(_ sound: CommandRushSound) {
        guard let player = players[sound] else {
            AudioServicesPlaySystemSound(1104)
            return
        }
        player.currentTime = 0
        player.play()
    }

    private func makePlayer(name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}
