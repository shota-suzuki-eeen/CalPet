//
//  BGMManager.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/10.
//

import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
final class BGMManager: ObservableObject {

    // ✅ 仕様：アセット名（ユーザー指定）
    private let bgmAssetName: String = "もじゃもじゃ日和"

    private var player: AVAudioPlayer?

    // ✅ 多重起動防止（startIfNeeded用）
    private var hasPrepared: Bool = false

    // MARK: - Public

    /// ✅ すでに再生中なら何もしない。止まっていたら再開する。
    func startIfNeeded() {
        // すでに再生中なら終了
        if let player, player.isPlaying { return }

        // 準備済みなら再開
        if hasPrepared, let player {
            player.play()
            return
        }

        // 未準備なら準備して再生
        prepareAndPlay()
    }

    /// ✅ 停止（現仕様では基本呼ばないが、将来の設定ON/OFF用）
    func stop() {
        player?.stop()
    }

    // MARK: - Private

    private func prepareAndPlay() {
        do {
            // ✅ BGMなのでミュートスイッチに従う（必要なら .playback に変更）
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)

            // 1) Bundle内ファイルとして探す（拡張子不明なので候補を順に）
            if let url = findAudioFileURLInBundle(named: bgmAssetName) {
                let p = try AVAudioPlayer(contentsOf: url)
                configureAndPlay(player: p)
                return
            }

            // 2) Data Asset として探す（Assets.xcassets -> Data Set）
            if let data = NSDataAsset(name: bgmAssetName)?.data {
                let p = try AVAudioPlayer(data: data)
                configureAndPlay(player: p)
                return
            }

            // 見つからない場合
            print("❌ BGMが見つかりません: \(bgmAssetName)\n- Bundle音源 or Data Asset を確認してください。")
        } catch {
            print("❌ BGM再生準備に失敗: \(error.localizedDescription)")
        }
    }

    private func configureAndPlay(player p: AVAudioPlayer) {
        p.numberOfLoops = -1      // ✅ 無限ループ
        p.volume = 0.7            // ✅ お好みで調整
        p.prepareToPlay()
        p.play()

        self.player = p
        self.hasPrepared = true
    }

    private func findAudioFileURLInBundle(named name: String) -> URL? {
        // よくある拡張子を順に試す（必要なら追加OK）
        let exts = ["m4a", "mp3", "wav", "aif", "aiff", "caf"]
        for ext in exts {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
