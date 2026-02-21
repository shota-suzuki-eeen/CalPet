//
//  MojaViewModel.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/21.
//

import Foundation
import SwiftUI
import Combine

/// ✅ MojaView 用 ViewModel（MVVM）
@MainActor
final class MojaViewModel: ObservableObject {

    // MARK: - Published (UI)

    @Published private(set) var mojaCount: Int = 0

    @Published private(set) var fusionIsRunning: Bool = false
    @Published private(set) var fusionEndAt: Date? = nil

    /// fusion中：0〜(count-1) を回す
    @Published private(set) var fusionFrameIndex: Int = 0

    /// 画面中央トースト用（View側で表示してOK）
    @Published var centerToastMessage: String? = nil
    @Published var showCenterToast: Bool = false

    // MARK: - Constants

    /// デモ用：1個消費（将来調整）
    let fusionCost: Int = 1

    /// 6時間
    private let fusionDuration: TimeInterval = 6 * 60 * 60

    /// 画像切り替え（仕様：moja → A → B → C → moja...）
    let fusionFrameAssetNames: [String] = [
        "moja",
        "moja_fusionA",
        "moja_fusionB",
        "moja_fusionC"
    ]

    // ✅ 1秒Ticker（安定化：TimerではなくTaskで回す）
    private var tickerTask: Task<Void, Never>?

    // MARK: - Storage Keys

    private enum Keys {
        static let mojaCount = "mojaCount"
        static let fusionIsRunning = "mojaFusionIsRunning"
        static let fusionEndAt = "mojaFusionEndAt" // Double (timeIntervalSince1970)
    }

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromStorage()

        // ✅ 起動時に進行中ならTickerを再開
        if fusionIsRunning {
            startTickerIfNeeded()
        }
    }

    deinit {
        tickerTask?.cancel()
    }

    // MARK: - Public API

    /// View の onAppear で呼ぶ想定
    func onAppearPrepareDemoIfNeeded() {
        // デモ用：初回だけ1個配布（不要なら削除OK）
        if mojaCount <= 0 && fusionIsRunning == false {
            mojaCount = 1
            persistMojaCount()
        }

        // ✅ 進行中ならTicker復帰（念のため）
        if fusionIsRunning {
            startTickerIfNeeded()
        }
    }

    /// （互換用）1秒ごとに呼ぶ想定だったが、安定化のため内部Task運用へ
    /// 既存コードを壊さないため残す（呼ばれても害はない）
    func tick(now: Date, state: AppState) {
        // Task運用に寄せたので基本は何もしない
        // ただし、呼ばれたなら完了判定だけはしておく
        syncFusionIfNeeded(now: now, state: state)
    }

    /// 「もじゃをまとめる」押下
    func startFusion(now: Date) {
        guard fusionIsRunning == false else { return }
        guard mojaCount >= fusionCost else {
            toastCenter("もじゃが足りない…")
            return
        }

        mojaCount -= fusionCost
        persistMojaCount()

        fusionIsRunning = true
        fusionFrameIndex = 0

        let end = now.addingTimeInterval(fusionDuration)
        fusionEndAt = end

        persistFusionProgress()

        toastCenter("もじゃがまとまり始めた！")

        // ✅ ここでTicker開始
        startTickerIfNeeded()
    }

    /// 「広告視聴で時間を短縮」押下（デモ：指定秒数だけ短縮）
    func applyAdReduction(seconds: TimeInterval, now: Date, state: AppState) {
        guard fusionIsRunning else { return }
        guard let end = fusionEndAt else { return }

        let reduce = max(0, seconds)
        if reduce <= 0 { return }

        let newEnd = end.addingTimeInterval(-reduce)
        fusionEndAt = newEnd
        persistFusionProgress()

        toastCenter("時間を短縮した！")

        // 直後に0判定
        syncFusionIfNeeded(now: now, state: state)
    }

    /// ✅ 現在表示するアセット名（View側で使ってOK）
    func currentFusionAssetName() -> String {
        if fusionIsRunning {
            let idx = max(0, min(fusionFrameIndex, fusionFrameAssetNames.count - 1))
            return fusionFrameAssetNames[idx]
        } else {
            return "moja"
        }
    }

    /// 残り秒数（fusion中のみ）
    func remainingSeconds(now: Date) -> TimeInterval {
        guard fusionIsRunning, let end = fusionEndAt else { return fusionDuration }
        return max(0, end.timeIntervalSince(now))
    }

    func formattedRemaining(now: Date) -> String {
        let sec = Int(remainingSeconds(now: now))
        let h = sec / 3600
        let m = (sec % 3600) / 60
        let s = sec % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // MARK: - Private (Ticker)

    private func startTickerIfNeeded() {
        guard tickerTask == nil else { return }

        tickerTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                // 進行が止まったら終了
                if self.fusionIsRunning == false {
                    break
                }

                // 1秒待つ（RunLoopに依存しない）
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                if Task.isCancelled { break }
                if self.fusionIsRunning == false { break }

                // フレームを進める（見た目用）
                self.fusionFrameIndex = (self.fusionFrameIndex + 1) % self.fusionFrameAssetNames.count
            }

            // 後始末
            await MainActor.run {
                self.tickerTask = nil
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    // MARK: - Private (Fusion)

    private func syncFusionIfNeeded(now: Date, state: AppState) {
        guard fusionIsRunning, let end = fusionEndAt else { return }

        if now >= end {
            // 完了
            fusionIsRunning = false
            fusionEndAt = nil
            fusionFrameIndex = 0
            persistFusionProgress()

            // ✅ Ticker停止
            stopTicker()

            grantRandomPet(state: state)
        }
    }

    private func grantRandomPet(state: AppState) {
        state.ensureInitialPetsIfNeeded()

        let owned = Set(state.ownedPetIDs())
        let candidates = PetMaster.all.map(\.id).filter { !owned.contains($0) }

        guard let newId = candidates.randomElement() else {
            toastCenter("全部のキャラを持っている！")
            return
        }

        var ids = state.ownedPetIDs()
        ids.append(newId)
        state.setOwnedPetIDs(ids)

        if let item = PetMaster.all.first(where: { $0.id == newId }) {
            toastCenter("新キャラ「\(item.name)」をゲット！")
        } else {
            toastCenter("新キャラをゲット！")
        }
    }

    private func toastCenter(_ message: String) {
        centerToastMessage = message
        withAnimation(.easeOut(duration: 0.15)) {
            showCenterToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.showCenterToast = false
            }
        }
    }

    // MARK: - Storage

    private func loadFromStorage() {
        mojaCount = defaults.integer(forKey: Keys.mojaCount)

        fusionIsRunning = defaults.bool(forKey: Keys.fusionIsRunning)

        let endRaw = defaults.double(forKey: Keys.fusionEndAt)
        if endRaw > 0 {
            fusionEndAt = Date(timeIntervalSince1970: endRaw)
        } else {
            fusionEndAt = nil
        }

        if fusionIsRunning == false {
            fusionFrameIndex = 0
        } else {
            fusionFrameIndex = fusionFrameIndex % max(1, fusionFrameAssetNames.count)
        }
    }

    private func persistMojaCount() {
        defaults.set(mojaCount, forKey: Keys.mojaCount)
    }

    private func persistFusionProgress() {
        defaults.set(fusionIsRunning, forKey: Keys.fusionIsRunning)

        if let end = fusionEndAt {
            defaults.set(end.timeIntervalSince1970, forKey: Keys.fusionEndAt)
        } else {
            defaults.set(0, forKey: Keys.fusionEndAt)
        }
    }
}
