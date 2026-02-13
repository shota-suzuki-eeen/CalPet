//
//  HomeView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    // ✅ Rootから渡された“同一のAppState”を使う
    let state: AppState

    @ObservedObject var hk: HealthKitManager

    // ✅ 初回のみ目標設定シートを出すためのフラグ（AppStateに持たせずUserDefaultsで保持）
    @AppStorage("didSetDailyGoalOnce") private var didSetDailyGoalOnce: Bool = false

    // 表示用
    @State private var todaySteps: Int = 0

    // ✅ 今日の通貨kcal（Active + Basal 合計）を表示に使う
    @State private var todayKcal: Int = 0

    // ✅ リング中央表示（演出でカウントアップさせる）
    @State private var displayedTodayKcal: Int = 0

    // ✅ 所持通貨表示（演出でカウントアップ/ダウンさせる）
    @State private var displayedWalletKcal: Int = 0

    // 目標入力（初回必須）
    @State private var showGoalSheet: Bool = false

    // ✅ 今日の一枚（撮影ボタンに紐づける）
    @State private var todayPhotoItem: PhotosPickerItem?
    @State private var todayPhotoImage: UIImage?
    @State private var todayPhotoEntry: TodayPhotoEntry?

    // ✅ 撮影ボタンで開くピッカー制御
    @State private var showPhotoPicker: Bool = false

    // 軽いトースト（保存完了など）
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    // ✅ メーター演出用（表示値を別で持って滑らかに伸ばす）
    @State private var displayedFriendship: Double = 0

    /// ✅ リング進捗（1周目=0..1、2周目以降=1..2..）
    @State private var displayedKcalProgress: Double = 0

    // gain演出
    @State private var isAnimatingGain: Bool = false

    // ✅ Home表示中か（ショップ滞在中に onChange が走っても演出しない）
    @State private var isHomeVisible: Bool = false

    // 進捗比較用
    @State private var lastFriendshipPoint: Int = 0
    @State private var lastTodayKcal: Int = 0

    // ✅ MAX到達時チケット演出
    @State private var showTicketOverlay: Bool = false
    @State private var ticketScale: CGFloat = 0.8
    @State private var ticketOpacity: Double = 0.0
    @State private var getOpacity: Double = 0.0

    // ✅ get 回転用（get_a / get_b 共通の角度。get_b は逆回転で表示）
    @State private var getRotation: Double = 0.0

    // ✅ ごはん棚
    @State private var showFoodShelf: Bool = false

    // ✅ ドロップターゲット演出（必要なら将来使える）
    @State private var isDropTargeted: Bool = false

    // =========================================================
    // ✅ キャラクターアニメ（仕様追加：アイドルまばたき / タップジャンプ）
    // =========================================================
    @State private var characterAssetName: String = "purpor"

    /// アイドリング（まばたき）用ループTask
    @State private var idleLoopTask: Task<Void, Never>?

    /// タップアクション（ジャンプ）中フラグ（アイドリング停止）
    @State private var isCharacterActionRunning: Bool = false

    // MARK: - Layout（ここだけ触ればUI調整しやすい）
    // ✅ ここを private -> fileprivate に変更（KcalRing から参照できるようにする）
    fileprivate enum Layout {
        // ===== 全体 =====
        static let bannerHeight: CGFloat = 76   // ✅ “バナーがあった時の高さ”をレイアウト保持に使う（表示はしない）

        // ✅ 仕様：Home背景画像アセット名
        static let homeBackgroundAssetName: String = "Home_background"

        // ===== 左上：メーター周り =====
        static let leftTopPaddingTop: CGFloat = 44
        static let leftTopPaddingLeading: CGFloat = 18
        static let meterStackSpacing: CGFloat = 18

        static let iconHeartSize: CGFloat = 31
        static let iconCoinSize: CGFloat = 26
        static let capsuleHeight: CGFloat = 23

        static let barWidth: CGFloat = 125
        static let walletWidth: CGFloat = 125
        static let redMinWidth: CGFloat = 18

        // ===== 右上：リング =====
        static let kcalRingTop: CGFloat = 36
        static let kcalRingTrailing: CGFloat = 18
        static let kcalRingSizeOuter: CGFloat = 135
        static let kcalRingSizeInner: CGFloat = 115

        // ===== 中央：キャラクター =====
        static let characterTopOffset: CGFloat = 45
        static let characterMaxWidth: CGFloat = 160

        // ===== 右側：縦ボタン群 =====
        static let rightButtonsTopOffset: CGFloat = 210
        static let rightButtonsTrailing: CGFloat = 20
        static let rightButtonSize: CGFloat = 40
        static let rightButtonsSpacing: CGFloat = 18

        // ===== 下部：横ボタン群 =====
        static let bottomButtonSize: CGFloat = 60
        static let bottomButtonsSpacing: CGFloat = 14
        static let bottomPadding: CGFloat = 80
        static let bottomHorizontalPadding: CGFloat = 14

        // ===== ごはん棚 =====
        static let foodShelfHeight: CGFloat = 45
        static let foodShelfHorizontalPadding: CGFloat = 18
        static let foodShelfBottomGapFromButtons: CGFloat = 120  // BottomButtons からの上方向オフセット
        static let foodItemSize: CGFloat = 64

        // ===== チケット演出 =====
        static let ticketMaxWidth: CGFloat = 220
        static let getMaxWidth: CGFloat = 240
        static let getTextMaxWidth: CGFloat = 200

        // ✅ get_text：チケットの上部に、少し「右＆上」
        static let getTextOffsetX: CGFloat = 11
        static let getTextOffsetY: CGFloat = -140

        // ✅ get 回転スピード（大きいほどゆっくり）
        static let getRotationDuration: Double = 2.2

        // ✅ リング中央テキスト周り
        static let kcalCenterCurrentFont: CGFloat = 18
        static let kcalCenterGoalFont: CGFloat = 12
        static let kcalCenterDividerHeight: CGFloat = 1
        static let kcalCenterDividerWidthRatio: CGFloat = 0.62   // innerSize * 0.62
        static let kcalCenterSpacing: CGFloat = 4
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ✅ 背景は「画面全体（セーフエリア含む）」に敷く
                Image(Layout.homeBackgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea() // ← 上部の“空白”を確実に消す

                VStack(spacing: 0) {
                    // ✅ バナーは表示しないが「高さ分の空間」は保持して、既存UI位置を一切ずらさない
                    Color.clear
                        .frame(height: Layout.bannerHeight)
                        .frame(maxWidth: .infinity)

                    // バナー下のステージ（ここから下は“バナーがあった時と同じ座標系”）
                    GeometryReader { geo in
                        let characterWidth = min(geo.size.width * 0.62, Layout.characterMaxWidth)

                        ZStack {
                            // =========================
                            // 1) キャラクター（中央）
                            // =========================
                            ZStack {
                                // ✅ ドロップ判定 + タップ判定（ここがキャラの当たり判定）
                                Rectangle()
                                    .fill(Color.black.opacity(0.001)) // 0 だと不安定なことがある
                                    .frame(width: characterWidth, height: characterWidth * 1.15)
                                    .offset(y: Layout.characterTopOffset)
                                    .zIndex(50)
                                    // ✅ タップ時：ジャンプ（アイドル停止）
                                    .highPriorityGesture(
                                        TapGesture().onEnded {
                                            triggerCharacterJump()
                                        }
                                    )
                                    .onDrop(
                                        of: [UTType.plainText.identifier, UTType.text.identifier],
                                        isTargeted: $isDropTargeted
                                    ) { providers in
                                        guard let provider = providers.first else { return false }

                                        // 文字列として取り出す（FoodItemCell の draggable(food.id) を想定）
                                        provider.loadItem(
                                            forTypeIdentifier: UTType.plainText.identifier,
                                            options: nil
                                        ) { item, _ in
                                            let id: String? = {
                                                if let s = item as? String { return s }
                                                if let data = item as? Data, let s = String(data: data, encoding: .utf8) { return s }
                                                if let url = item as? URL { return url.absoluteString }
                                                return nil
                                            }()

                                            guard let foodId = id else { return }

                                            DispatchQueue.main.async {
                                                _ = handleFoodDrop(foodId: foodId, state: state)
                                            }
                                        }

                                        // 受け入れは即 true（処理は非同期）
                                        return true
                                    }

                                // ✅ 表示するキャラ画像を差し替え（アニメ用）
                                Image(characterAssetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: characterWidth)
                                    .offset(y: Layout.characterTopOffset)
                                    .allowsHitTesting(false) // タッチ判定は上のRectが担当
                            }

                            // ==================================
                            // 2) 左上：なかよし度 + 所持kcal
                            // ==================================
                            VStack(alignment: .leading, spacing: Layout.meterStackSpacing) {
                                FriendshipMeter(
                                    value: displayedFriendship,
                                    maxValue: Double(AppState.friendshipMaxMeter),
                                    barWidth: Layout.barWidth,
                                    height: Layout.capsuleHeight,
                                    iconSize: Layout.iconHeartSize,
                                    redMinWidth: Layout.redMinWidth
                                )

                                WalletCapsule(
                                    walletKcal: displayedWalletKcal, // ✅ 演出用表示値
                                    barWidth: Layout.walletWidth,
                                    height: Layout.capsuleHeight,
                                    iconSize: Layout.iconCoinSize
                                )

                                Spacer()
                            }
                            .padding(.top, Layout.leftTopPaddingTop)
                            .padding(.leading, Layout.leftTopPaddingLeading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                            // =========================
                            // 3) 右上：消費kcalリング
                            // =========================
                            KcalRing(
                                progress: displayedKcalProgress,     // ✅ 1.0超えを許可（2周目は緑）
                                currentKcal: displayedTodayKcal,     // ✅ 演出で増える表示
                                goalKcal: state.dailyGoalKcal,
                                outerSize: Layout.kcalRingSizeOuter,
                                innerSize: Layout.kcalRingSizeInner
                            )
                            .padding(.top, Layout.kcalRingTop)
                            .padding(.trailing, Layout.kcalRingTrailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                            // =========================
                            // 4) 右側：縦ボタン群
                            // =========================
                            RightSideButtons(
                                state: state,
                                onCamera: { showPhotoPicker = true },
                                buttonSize: Layout.rightButtonSize,
                                spacing: Layout.rightButtonsSpacing
                            )
                            .padding(.top, Layout.rightButtonsTopOffset)
                            .padding(.trailing, Layout.rightButtonsTrailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                            // =========================
                            // 4.5) ごはん棚（テロップ外タップで閉じる／棚上は閉じない）
                            // =========================
                            if showFoodShelf {
                                FoodShelfPanel(state: state)
                                    .padding(.horizontal, Layout.foodShelfHorizontalPadding)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    .padding(.bottom, Layout.bottomPadding + Layout.foodShelfBottomGapFromButtons)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                    .onTapGesture { } // ✅ 棚の上タップは「背景タップ」に伝播させない
                            }

                            // =========================
                            // 5) 下部：横ボタン群（お世話ON表示対応）
                            // =========================
                            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                                let now = timeline.date

                                let canFood = state.canFeedNow(now: now).can
                                let canBath = state.canBathNow(now: now).can
                                let canWc = (state.toiletFlagAt != nil)
                                let canSleep = true

                                BottomButtons(
                                    onSleep: { addFriendshipWithAnimation(points: 5, state: state) },
                                    onBath: { onTapBath(state: state) },
                                    onFood: { onTapFood(state: state) },
                                    onWc: { onTapToilet(state: state) },
                                    onHome: { /* 何もしない */ },
                                    isSleepAvailable: canSleep,
                                    isBathAvailable: canBath,
                                    isFoodAvailable: canFood,
                                    isWcAvailable: canWc,
                                    buttonSize: Layout.bottomButtonSize,
                                    spacing: Layout.bottomButtonsSpacing,
                                    horizontalPadding: Layout.bottomHorizontalPadding
                                )
                            }
                            .padding(.bottom, Layout.bottomPadding)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                            // =========================
                            // 6) MAX到達：チケット演出（画面中央）
                            // =========================
                            if showTicketOverlay {
                                ZStack {
                                    Color.black.opacity(0.001)
                                        .ignoresSafeArea()
                                        .onTapGesture { dismissTicketOverlay() }

                                    ZStack {
                                        // ✅ get → get_a に置換 + get_b を重ねて逆回転
                                        ZStack {
                                            Image("get_a")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: min(geo.size.width * 0.78, Layout.getMaxWidth))
                                                .opacity(getOpacity)
                                                .rotationEffect(.degrees(getRotation))

                                            Image("get_b")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: min(geo.size.width * 0.78, Layout.getMaxWidth))
                                                .opacity(getOpacity)
                                                .rotationEffect(.degrees(getRotation * 0.85))
                                        }

                                        Image("ticket")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: min(geo.size.width * 0.7, Layout.ticketMaxWidth))
                                            .opacity(ticketOpacity)
                                            .scaleEffect(ticketScale)

                                        Image("get_text")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: min(geo.size.width * 0.62, Layout.getTextMaxWidth))
                                            .offset(x: Layout.getTextOffsetX, y: Layout.getTextOffsetY)
                                            .opacity(ticketOpacity)
                                            .scaleEffect(ticketScale)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // ✅ ステージ背景タップで閉じる（全画面透明レイヤーは使わない＝D&Dを邪魔しない）
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard showFoodShelf else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showFoodShelf = false
                            }
                        }
                        // Toast
                        .overlay(alignment: .bottom) {
                            if showToast, let toastMessage {
                                ToastView(message: toastMessage)
                                    .padding(.bottom, 18)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $todayPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: todayPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task { await setTodayPhoto(from: newValue) }
        }
        .task {
            state.ensureInitialPetsIfNeeded()

            if state.dailyGoalKcal > 0, didSetDailyGoalOnce == false {
                didSetDailyGoalOnce = true
            }

            // 起動直後はキャッシュをまず表示
            todaySteps = state.cachedTodaySteps
            todayKcal = state.cachedTodayKcal

            // ✅ 初期表示（演出用表示値もここで合わせる）
            displayedTodayKcal = todayKcal
            displayedWalletKcal = state.walletKcal

            displayedFriendship = Double(state.friendshipPoint)
            displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)

            lastFriendshipPoint = state.friendshipPoint
            lastTodayKcal = todayKcal

            handleDayRolloverIfNeeded(state: state)

            await runSync(state: state)
            maybeSpawnToiletFlag(state: state)
            loadTodayPhoto()

            if !didSetDailyGoalOnce, state.dailyGoalKcal <= 0 {
                showGoalSheet = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            state.ensureInitialPetsIfNeeded()

            // 復帰直後もまずはキャッシュで表示（0チラつき防止）
            todaySteps = state.cachedTodaySteps
            todayKcal = state.cachedTodayKcal

            // ✅ リングはキャッシュに合わせて即座に整える（通貨は“戻ってきた時演出”のためここでは同期しない）
            displayedTodayKcal = todayKcal
            displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)

            handleDayRolloverIfNeeded(state: state)

            Task {
                await runSync(state: state)
                maybeSpawnToiletFlag(state: state)
                loadTodayPhoto()

                // ✅ フォアグラ復帰時にHomeが見えているなら、必要に応じて差分演出で追従
                if isHomeVisible {
                    await reconcileWalletDisplayIfNeeded(state: state)
                }
            }
        }
        .sheet(isPresented: $showGoalSheet) {
            GoalSettingSheet(
                currentGoal: state.dailyGoalKcal,
                isDismissDisabled: state.dailyGoalKcal <= 0,
                onSave: { newGoal in
                    state.dailyGoalKcal = newGoal
                    didSetDailyGoalOnce = true
                    save()

                    withAnimation(.easeOut(duration: 0.35)) {
                        displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
                    }

                    showGoalSheet = false
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            isHomeVisible = true

            // ✅ キャラのアイドルアニメ開始（Home表示中のみ）
            startCharacterIdleLoopIfNeeded()

            // リングは即追従（演出は増加時のみ runSync 側）
            withAnimation(.easeOut(duration: 0.25)) {
                displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
            }

            // ✅ 通貨の減少（ショップ消費など）を検知してカウントダウン
            Task { await reconcileWalletDisplayIfNeeded(state: state) }
        }
        .onDisappear {
            isHomeVisible = false
            // 念のため、Home離脱時に振動停止
            Haptics.stopRattle()

            // ✅ キャラアニメ停止
            stopCharacterIdleLoop()
            isCharacterActionRunning = false
            characterAssetName = "purpor"
        }
        // ✅ wallet が裏で更新された場合も追従（ショップ購入など）
        .onChange(of: state.walletKcal) { _, _ in
            guard isHomeVisible else { return }
            Task { await reconcileWalletDisplayIfNeeded(state: state) }
        }
        .onChange(of: state.dailyGoalKcal) { _, _ in
            if state.dailyGoalKcal > 0, didSetDailyGoalOnce == false {
                didSetDailyGoalOnce = true
            }
            withAnimation(.easeOut(duration: 0.25)) {
                displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
            }
        }
    }

    // MARK: - キャラクターアニメ制御
    private func startCharacterIdleLoopIfNeeded() {
        guard idleLoopTask == nil else { return }

        idleLoopTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)

            while !Task.isCancelled {
                if !isHomeVisible {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    continue
                }

                if isCharacterActionRunning {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    continue
                }

                let wait = Double.random(in: 2.2...6.0)
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))

                if Task.isCancelled { break }
                if !isHomeVisible { continue }
                if isCharacterActionRunning { continue }

                await playBlink()
            }
        }
    }

    private func stopCharacterIdleLoop() {
        idleLoopTask?.cancel()
        idleLoopTask = nil
    }

    private func triggerCharacterJump() {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }
        Task { await playJump() }
    }

    private func playBlink() async {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }

        await MainActor.run { characterAssetName = "purpor_idle_blink_0001" }
        try? await Task.sleep(nanoseconds: 70_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }

        await MainActor.run { characterAssetName = "purpor_idle_blink_0002" }
        try? await Task.sleep(nanoseconds: 60_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }

        await MainActor.run { characterAssetName = "purpor_idle_blink_0003" }
        try? await Task.sleep(nanoseconds: 70_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }

        await MainActor.run { characterAssetName = "purpor" }
    }

    private func playJump() async {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }

        await MainActor.run {
            isCharacterActionRunning = true
            characterAssetName = "purpor_tap_0001"
        }
        try? await Task.sleep(nanoseconds: 80_000_000)

        await MainActor.run { characterAssetName = "purpor_tap_0002" }
        try? await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run { characterAssetName = "purpor_tap_0003" }
        try? await Task.sleep(nanoseconds: 90_000_000)

        await MainActor.run {
            characterAssetName = "purpor"
            isCharacterActionRunning = false
        }
    }

    // MARK: - Drag & Drop（ごはんをドロップして「あげる」）
    private func handleFoodDrop(foodId: String, state: AppState) -> Bool {
        guard let food = FoodCatalog.byId(foodId) else {
            toast("ご飯が見つかりません")
            return false
        }

        let check = state.canFeedNow(now: Date())
        guard check.can, let slot = check.slot else {
            toast(check.reason ?? "今はご飯できません")
            return false
        }

        guard state.foodCount(foodId: foodId) > 0 else {
            toast("そのご飯は所持していません")
            return false
        }

        let ok = state.consumeFood(foodId: foodId, count: 1)
        guard ok else {
            toast("消費に失敗しました")
            return false
        }

        state.setFed(slot: slot, value: true)
        save()

        addFriendshipWithAnimation(points: 10, state: state)
        toast("\(food.name)をあげた！ +10")

        withAnimation(.easeInOut(duration: 0.18)) {
            showFoodShelf = false
        }
        return true
    }

    // MARK: - UI helpers
    private func calcKcalProgressRaw(todayKcal: Int, goalKcal: Int) -> Double {
        guard goalKcal > 0 else { return 0 }
        return Double(todayKcal) / Double(goalKcal)
    }

    private func reconcileWalletDisplayIfNeeded(state: AppState) async {
        guard isHomeVisible else { return }
        guard !isAnimatingGain else { return }

        let target = state.walletKcal

        if displayedWalletKcal > target {
            await playWalletCountDownAnimation(from: displayedWalletKcal, to: target)
            return
        }

        if displayedWalletKcal != target {
            await MainActor.run { displayedWalletKcal = target }
        }
    }

    private func playWalletCountDownAnimation(from: Int, to: Int) async {
        guard isHomeVisible else { return }
        guard from > to else { return }
        guard !isAnimatingGain else { return }

        let magnitude = from - to
        let duration = min(1.2, max(0.25, Double(magnitude) * 0.006))

        let fps: Double = 60
        let frames = max(1, Int(duration * fps))

        await MainActor.run {
            Haptics.startRattle(style: .light, interval: 0.04, intensity: 0.65)
        }

        for i in 0...frames {
            if !isHomeVisible { break }

            let t = Double(i) / Double(frames)
            let eased = 1 - pow(1 - t, 3)

            let v = from - Int(Double(magnitude) * eased)

            await MainActor.run {
                displayedWalletKcal = max(to, v)
            }

            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / fps))
        }

        await MainActor.run {
            displayedWalletKcal = to
            Haptics.stopRattle()
        }
    }

    // MARK: - Friendship points
    private func addFriendshipWithAnimation(points: Int, state: AppState) {
        guard points > 0 else { return }

        let maxMeter = AppState.friendshipMaxMeter
        let beforeDisplayed = displayedFriendship

        let result = state.addFriendship(points: points, maxMeter: maxMeter)
        save()

        let after = result.afterPoint

        Task { @MainActor in
            Haptics.rattle(duration: 0.50, style: .medium)
        }

        if result.didWrap {
            withAnimation(.easeOut(duration: 0.35)) {
                displayedFriendship = Double(maxMeter)
            }

            triggerTicketOverlay()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.37) {
                displayedFriendship = 0
                withAnimation(.easeOut(duration: 0.55)) {
                    displayedFriendship = Double(after)
                }
            }
        } else {
            displayedFriendship = beforeDisplayed
            withAnimation(.easeOut(duration: 0.65)) {
                displayedFriendship = Double(after)
            }
        }

        lastFriendshipPoint = after
    }

    private func triggerTicketOverlay() {
        showTicketOverlay = false
        ticketScale = 0.8
        ticketOpacity = 0.0
        getOpacity = 0.0
        getRotation = 0.0

        withAnimation(.easeOut(duration: 0.12)) {
            showTicketOverlay = true
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
            ticketScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.18)) {
            ticketOpacity = 1.0
            getOpacity = 1.0
        }

        withAnimation(.linear(duration: Layout.getRotationDuration).repeatForever(autoreverses: false)) {
            getRotation = 360
        }
    }

    private func dismissTicketOverlay() {
        withAnimation(.easeInOut(duration: 0.18)) {
            ticketOpacity = 0.0
            getOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.12)) {
                showTicketOverlay = false
            }
            ticketScale = 0.8
            getRotation = 0.0
        }
    }

    // MARK: - 今日の一枚
    private func loadTodayPhoto() {
        let key = AppState.makeDayKey(Date())
        do {
            let descriptor = FetchDescriptor<TodayPhotoEntry>(
                predicate: #Predicate { $0.dayKey == key }
            )
            let found = try modelContext.fetch(descriptor).first
            todayPhotoEntry = found
            if let fileName = found?.fileName {
                todayPhotoImage = TodayPhotoStorage.loadImage(fileName: fileName)
            } else {
                todayPhotoImage = nil
            }
        } catch {
            todayPhotoEntry = nil
            todayPhotoImage = nil
        }
    }

    private func setTodayPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                toast("画像の読み込みに失敗しました")
                return
            }

            let key = AppState.makeDayKey(Date())
            let fileName = "\(key).jpg"

            try TodayPhotoStorage.saveJPEG(uiImage, fileName: fileName, quality: 0.9)

            let now = Date()
            let descriptor = FetchDescriptor<TodayPhotoEntry>(
                predicate: #Predicate { $0.dayKey == key }
            )
            let existing = try modelContext.fetch(descriptor).first

            if let existing {
                existing.date = now
                existing.fileName = fileName
                todayPhotoEntry = existing
            } else {
                let created = TodayPhotoEntry(dayKey: key, date: now, fileName: fileName)
                modelContext.insert(created)
                todayPhotoEntry = created
            }

            save()
            todayPhotoImage = uiImage
            toast("今日の一枚を保存しました")
            Task { @MainActor in
                Haptics.rattle(duration: 0.18, style: .light)
            }
        } catch {
            toast("保存に失敗しました")
        }
    }

    // MARK: - Toast
    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) { showToast = false }
        }
    }

    // MARK: - Care (Feed / Bath / Toilet)
    private func onTapFood(state: AppState) {
        Task { @MainActor in
            Haptics.rattle(duration: 0.12, style: .light)
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            showFoodShelf.toggle()
        }
    }

    private func onTapBath(state: AppState) {
        let now = Date()
        let bath = state.canBathNow(now: now)

        if bath.can {
            state.markBathDone(now: now)
            save()
            addFriendshipWithAnimation(points: 15, state: state)
            toast("お風呂に入った！ +15")
            return
        }

        let ad = state.canUseBathAd(now: now)
        guard ad.can else {
            toast(ad.reason ?? "まだお風呂はできません")
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            return
        }

        state.applyBathAdReduction(now: now)
        save()

        let after = state.canBathNow(now: now)
        toast(after.can ? "広告で短縮！お風呂できます" : "広告でクールタイム短縮！")
        Task { @MainActor in
            Haptics.rattle(duration: 0.18, style: after.can ? .medium : .light)
        }
    }

    private func onTapToilet(state: AppState) {
        if state.toiletFlagAt != nil {
            resolveToilet(state: state)
            return
        }

        maybeSpawnToiletFlag(state: state)
        Task { @MainActor in
            Haptics.rattle(duration: 0.18, style: .light)
        }
    }

    private func maybeSpawnToiletFlag(state: AppState) {
        guard state.toiletFlagAt == nil else { return }
        guard state.canRaiseToiletFlag(now: Date()) else { return }

        let roll = Int.random(in: 1...100)
        if roll <= 20 {
            if state.raiseToiletFlag(now: Date()) {
                save()
                toast("トイレ行きたい！")
            }
        }
    }

    private func resolveToilet(state: AppState) {
        let r = state.resolveToilet(now: Date())
        guard r.didResolve else { return }

        addFriendshipWithAnimation(points: r.isWithin1h ? 20 : 10, state: state)
        toast(r.isWithin1h ? "トイレ成功（1時間以内）+20" : "トイレ成功 +10")
        save()
    }

    // MARK: - AppState
    private func save() {
        do { try modelContext.save() } catch { }
    }

    private func handleDayRolloverIfNeeded(state: AppState) {
        let now = Date()
        let todayKey = AppState.makeDayKey(now)
        guard state.lastDayKey == todayKey else {
            state.ensureDailyResetIfNeeded(now: now)

            state.lastSyncedAt = Calendar.current.startOfDay(for: now)
            state.eggAdUsedToday = false

            save()
            loadTodayPhoto()
            return
        }
    }

    private func runSync(state: AppState) async {
        guard hk.authState == .authorized else { return }

        let previousCachedSteps = state.cachedTodaySteps
        let previousCachedKcal = state.cachedTodayKcal

        let beforeDisplayedTodayKcal = displayedTodayKcal
        let beforeDisplayedWallet = displayedWalletKcal

        let result = await hk.syncAndGetDeltaKcal(lastSyncedAt: state.lastSyncedAt)
        state.lastSyncedAt = result.newLastSyncedAt

        let fetchedSteps = hk.todaySteps
        let fetchedKcal = hk.todayTotalEnergyKcal

        let shouldProtectSteps = (fetchedSteps == 0 && previousCachedSteps > 0)
        let shouldProtectKcal = (fetchedKcal == 0 && previousCachedKcal > 0)

        todaySteps = shouldProtectSteps ? previousCachedSteps : fetchedSteps
        todayKcal  = shouldProtectKcal ? previousCachedKcal : fetchedKcal

        if !shouldProtectSteps { state.cachedTodaySteps = todaySteps }
        if !shouldProtectKcal { state.cachedTodayKcal = todayKcal }

        if result.deltaKcal > 0 {
            state.pendingKcal += result.deltaKcal
        }
        save()

        await playGainAnimationIfNeeded(
            state: state,
            fromDisplayedTodayKcal: beforeDisplayedTodayKcal,
            fromDisplayedWallet: beforeDisplayedWallet
        )

        if !isAnimatingGain {
            displayedTodayKcal = todayKcal

            if isHomeVisible {
                displayedWalletKcal = state.walletKcal
            }

            withAnimation(.easeOut(duration: 0.25)) {
                displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
            }
        }

        lastTodayKcal = todayKcal
    }

    private func playGainAnimationIfNeeded(
        state: AppState,
        fromDisplayedTodayKcal: Int,
        fromDisplayedWallet: Int
    ) async {
        guard !isAnimatingGain else { return }

        let deltaWallet = state.pendingKcal
        let targetWallet = state.walletKcal + max(0, deltaWallet)
        let targetTodayKcal = todayKcal

        let hasAnyIncrease = (targetWallet > fromDisplayedWallet) || (targetTodayKcal > fromDisplayedTodayKcal)
        guard hasAnyIncrease else { return }

        isAnimatingGain = true

        if deltaWallet > 0 {
            state.pendingKcal = 0
            state.walletKcal = targetWallet
            save()
        }

        let totalMagnitude = max(targetWallet - fromDisplayedWallet, targetTodayKcal - fromDisplayedTodayKcal)
        let duration = min(1.6, max(0.45, Double(totalMagnitude) * 0.008))

        let fps: Double = 60
        let frames = max(1, Int(duration * fps))

        await MainActor.run {
            Haptics.startRattle(style: .light, interval: 0.03, intensity: 0.8)
        }

        for i in 0...frames {
            let t = Double(i) / Double(frames)
            let eased = 1 - pow(1 - t, 3)

            let newWallet = fromDisplayedWallet + Int(Double(targetWallet - fromDisplayedWallet) * eased)
            let newTodayKcal = fromDisplayedTodayKcal + Int(Double(targetTodayKcal - fromDisplayedTodayKcal) * eased)

            await MainActor.run {
                displayedWalletKcal = newWallet
                displayedTodayKcal = newTodayKcal
                displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
            }

            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / fps))
        }

        await MainActor.run {
            displayedWalletKcal = targetWallet
            displayedTodayKcal = targetTodayKcal
            displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
            Haptics.stopRattle()
        }

        isAnimatingGain = false
    }
}

// MARK: - UI Parts（画像再現用）

private struct BannerBar: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.22, green: 0.24, blue: 0.28))
    }
}

private struct FriendshipMeter: View {
    let value: Double
    let maxValue: Double

    let barWidth: CGFloat
    let height: CGFloat
    let iconSize: CGFloat
    let redMinWidth: CGFloat

    private var progress: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(min(1.0, value / maxValue))
    }

    private var rawWidth: CGFloat { barWidth * progress }
    private var baseWidth: CGFloat { Swift.max(redMinWidth, rawWidth) }
    private var scaleX: CGFloat {
        guard baseWidth > 0 else { return 0 }
        return rawWidth / baseWidth
    }

    var body: some View {
        HStack(spacing: 10) {
            Image("heart_Icon")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: barWidth, height: height)

                if rawWidth > 0 {
                    Capsule()
                        .fill(Color(red: 0.95, green: 0.12, blue: 0.12))
                        .frame(width: baseWidth, height: height)
                        .scaleEffect(x: scaleX, y: 1, anchor: .leading)
                }
            }
        }
    }
}

private struct WalletCapsule: View {
    let walletKcal: Int

    let barWidth: CGFloat
    let height: CGFloat
    let iconSize: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Image("coin_Icon")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: barWidth, height: height)

                Text("\(walletKcal) kcal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
    }
}

private struct KcalRing: View {
    let progress: Double
    let currentKcal: Int
    let goalKcal: Int

    let outerSize: CGFloat
    let innerSize: CGFloat

    private var goalText: String {
        goalKcal > 0 ? "\(goalKcal)" : "—"
    }

    private var lap1: CGFloat {
        CGFloat(min(1.0, max(0.0, progress)))
    }

    private var lap2: CGFloat {
        let v = progress - 1.0
        return CGFloat(min(1.0, max(0.0, v)))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.9))
                .frame(width: outerSize, height: outerSize)

            Circle()
                .stroke(lineWidth: 14)
                .opacity(0.18)
                .foregroundStyle(.white)
                .frame(width: innerSize, height: innerSize)

            Circle()
                .trim(from: 0, to: lap1)
                .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(-90))
                .frame(width: innerSize, height: innerSize)
                .animation(.easeOut(duration: 0.55), value: lap1)

            if lap2 > 0 {
                Circle()
                    .trim(from: 0, to: lap2)
                    .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .foregroundStyle(.green)
                    .rotationEffect(.degrees(-90))
                    .frame(width: innerSize, height: innerSize)
                    .animation(.easeOut(duration: 0.55), value: lap2)
            }

            VStack(spacing: HomeView.Layout.kcalCenterSpacing) {
                Text("\(currentKcal)")
                    .font(.system(size: HomeView.Layout.kcalCenterCurrentFont, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Rectangle()
                    .fill(Color.white.opacity(0.75))
                    .frame(
                        width: innerSize * HomeView.Layout.kcalCenterDividerWidthRatio,
                        height: HomeView.Layout.kcalCenterDividerHeight
                    )

                Text("\(goalText)")
                    .font(.system(size: HomeView.Layout.kcalCenterGoalFont, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: innerSize * 0.9)
        }
    }
}

private struct RightSideButtons: View {
    let state: AppState
    let onCamera: () -> Void

    let buttonSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        VStack(spacing: spacing) {
            Button(action: onCamera) {
                Image("camera_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            NavigationLink { MemoriesView() } label: {
                Image("omoide_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            NavigationLink { ZukanView() } label: {
                Image("picture_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            NavigationLink { ShopView(state: state) } label: {
                Image("shop_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            NavigationLink { SettingsView() } label: {
                Image("option_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }
        }
    }
}

private struct BottomButtons: View {
    let onSleep: () -> Void
    let onBath: () -> Void
    let onFood: () -> Void
    let onWc: () -> Void
    let onHome: () -> Void

    let isSleepAvailable: Bool
    let isBathAvailable: Bool
    let isFoodAvailable: Bool
    let isWcAvailable: Bool

    let buttonSize: CGFloat
    let spacing: CGFloat
    let horizontalPadding: CGFloat

    private var sleepImageName: String { isSleepAvailable ? "sleep_button_on" : "sleep_button" }
    private var bathImageName: String { isBathAvailable ? "bath_button_on" : "bath_button" }
    private var foodImageName: String { isFoodAvailable ? "food_button_on" : "food_button" }
    private var wcImageName: String { isWcAvailable ? "wc_button_on" : "wc_button" }

    var body: some View {
        HStack(spacing: spacing) {
            Button(action: onSleep) {
                Image(sleepImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            Button(action: onBath) {
                Image(bathImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            Button(action: onFood) {
                Image(foodImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            Button(action: onWc) {
                Image(wcImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            Button(action: onHome) {
                Image("home_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}

private struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 8)
    }
}

private struct GoalSettingSheet: View {
    let currentGoal: Int
    let isDismissDisabled: Bool
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("目標消費カロリー（kcal）") {
                    TextField("例：300", text: $text)
                        .keyboardType(.numberPad)

                    if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }

                    Text("当日中の変更も即時反映されます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("保存") {
                        guard let v = Int(text), v > 0 else {
                            error = "1以上の数値を入力してください。"
                            return
                        }
                        onSave(v)
                    }
                }
            }
            .navigationTitle("目標設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { if !isDismissDisabled { dismiss() } }
                        .disabled(isDismissDisabled)
                }
            }
        }
        .onAppear { text = currentGoal > 0 ? String(currentGoal) : "" }
    }
}

// MARK: - ごはん棚（仕様変更版）

private struct FoodShelfPanel: View {
    let state: AppState

    private var ownedFoods: [FoodCatalog.FoodItem] {
        FoodCatalog.all.filter { state.foodCount(foodId: $0.id) > 0 }
    }

    var body: some View {
        ZStack {
            // ✅ 土台：gohan_telop（枠線なし）
            Image("gohan_telop")
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .clipped()

            if ownedFoods.isEmpty {
                Text("ご飯がありません（ショップで購入してください）")
                    .font(.footnote)
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.horizontal, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ownedFoods) { food in
                            FoodItemCell(
                                food: food,
                                count: state.foodCount(foodId: food.id)
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(height: HomeView.Layout.foodShelfHeight)
    }
}

private struct FoodItemCell: View {
    let food: FoodCatalog.FoodItem
    let count: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(food.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: HomeView.Layout.foodItemSize, height: HomeView.Layout.foodItemSize)
                .padding(6)
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.45), lineWidth: 2)
                )
                // ✅ これを掴んでキャラにドロップする（プレビュー付き）
                .draggable(food.id) {
                    Image(food.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: HomeView.Layout.foodItemSize, height: HomeView.Layout.foodItemSize)
                }

            Text("x\(count)")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .padding(6)
        }
    }
}
