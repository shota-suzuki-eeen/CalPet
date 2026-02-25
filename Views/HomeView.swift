//
//  HomeView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import SwiftUI
import SwiftData
import UIKit
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
    @State private var todayKcal: Int = 0

    // ✅ リング中央表示（演出でカウントアップさせる）
    @State private var displayedTodayKcal: Int = 0

    // ✅ 所持通貨表示（演出でカウントアップ/ダウンさせる）
    @State private var displayedWalletKcal: Int = 0

    // ✅ 満足度（表示用：0..3）
    @State private var displayedSatisfaction: Int = 3

    // 目標入力（初回必須）
    @State private var showGoalSheet: Bool = false

    // ✅ 今日の一枚（撮影ボタンに紐づける）
    @State private var todayPhotoImage: UIImage?
    @State private var todayPhotoEntry: TodayPhotoEntry?

    // ✅ 撮影ボタンで開くキャプチャ画面制御
    @State private var showCaptureModeDialog: Bool = false
    @State private var selectedCaptureMode: CameraCaptureView.Mode?

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

    // ✅ MAX到達時 “もじゃ” 演出（旧: チケット）
    @State private var showMojaOverlay: Bool = false
    @State private var rewardScale: CGFloat = 0.8
    @State private var rewardOpacity: Double = 0.0
    @State private var getOpacity: Double = 0.0
    @State private var getRotation: Double = 0.0

    // ✅ ごはん棚
    @State private var showFoodShelf: Bool = false

    // ✅ ドロップターゲット演出
    @State private var isDropTargeted: Bool = false

    // ✅ 追加：ドラッグでキャラ上ホバー中か（表情差し替えのため）
    @State private var isFoodHoveringOverCharacter: Bool = false

    // =========================================================
    // ✅ キャラクターアニメ（アイドルまばたき / タップジャンプ）
    // =========================================================
    @State private var characterAssetName: String = "purpor"
    @State private var idleLoopTask: Task<Void, Never>?
    @State private var isCharacterActionRunning: Bool = false

    private let doubleBlinkChance: Double = 0.18
    private let doubleBlinkGapRange: ClosedRange<Double> = 0.18...0.45

    // ✅ 追加：現在育成中キャラの「ベースアセット名」
    private var currentBaseAssetName: String {
        PetMaster.assetName(for: state.currentPetID)
    }

    // ✅ 追加：purpor 以外はアニメ素材が無い想定なので保護
    private var canPlayCharacterAnimation: Bool {
        currentBaseAssetName == "purpor"
    }

    // ✅ 追加：満足度MAX判定（表示値ベースでOK）
    private var isSatisfactionMax: Bool {
        displayedSatisfaction >= Layout.satisfactionSegments
    }

    // MARK: - Layout
    fileprivate enum Layout {
        static let bannerHeight: CGFloat = 76
        static let homeBackgroundAssetName: String = "Home_background"

        static let leftTopPaddingTop: CGFloat = 44
        static let leftTopPaddingLeading: CGFloat = 18
        static let meterStackSpacing: CGFloat = 18

        static let iconHeartSize: CGFloat = 31
        static let iconCoinSize: CGFloat = 26
        static let capsuleHeight: CGFloat = 23

        static let barWidth: CGFloat = 125
        static let walletWidth: CGFloat = 125
        static let redMinWidth: CGFloat = 18

        // ✅ 満足度メーター（所持kcalの下）
        static let satisfactionSpacingFromWallet: CGFloat = 16
        static let satisfactionBarWidth: CGFloat = 125
        static let satisfactionBarHeight: CGFloat = 10
        static let satisfactionSegments: Int = 3
        static let satisfactionSegmentGap: CGFloat = 4
        static let satisfactionCornerRadius: CGFloat = 4

        // ✅ 満足度メーター用アイコン
        static let satisfactionIconAssetName: String = "food_Icon"
        static let satisfactionIconSize: CGFloat = 24
        static let satisfactionIconSpacing: CGFloat = 10

        static let kcalRingTop: CGFloat = 36
        static let kcalRingTrailing: CGFloat = 18
        static let kcalRingSizeOuter: CGFloat = 135
        static let kcalRingSizeInner: CGFloat = 115

        static let characterTopOffset: CGFloat = 45
        static let characterMaxWidth: CGFloat = 210

        static let rightButtonsTopOffset: CGFloat = 210
        static let rightButtonsTrailing: CGFloat = 20
        static let rightButtonSize: CGFloat = 40
        static let rightButtonsSpacing: CGFloat = 18

        static let bottomButtonSize: CGFloat = 60
        static let bottomButtonsSpacing: CGFloat = 14
        static let bottomPadding: CGFloat = 80
        static let bottomHorizontalPadding: CGFloat = 14

        static let foodShelfHeight: CGFloat = 45
        static let foodShelfHorizontalPadding: CGFloat = 18
        static let foodShelfBottomGapFromButtons: CGFloat = 120
        static let foodItemSize: CGFloat = 64

        // ✅ 報酬演出（旧: ticket）
        static let rewardMaxWidth: CGFloat = 220
        static let getMaxWidth: CGFloat = 240
        static let getTextMaxWidth: CGFloat = 200

        static let getTextOffsetX: CGFloat = 11
        static let getTextOffsetY: CGFloat = -160

        static let getRotationDuration: Double = 2.2

        static let kcalCenterCurrentFont: CGFloat = 18
        static let kcalCenterGoalFont: CGFloat = 12
        static let kcalCenterDividerHeight: CGFloat = 1
        static let kcalCenterDividerWidthRatio: CGFloat = 0.62
        static let kcalCenterSpacing: CGFloat = 4

        // ✅ zIndex（前後関係固定）
        static let zCharacter: Double = 50
        static let zFoodShelf: Double = 220
        static let zReward: Double = 300
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Image(Layout.homeBackgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // ✅ 修正：Home上部バナーは AdMob SDK型を直接触らず、AdBannerView に一本化
                    AdBannerView(height: Layout.bannerHeight)
                        .frame(height: Layout.bannerHeight)
                        .frame(maxWidth: .infinity)

                    GeometryReader { geo in
                        let characterWidth = min(geo.size.width * 0.62, Layout.characterMaxWidth)

                        ZStack {

                            // ✅ 追加：棚が開いている時、空きスペースをタップしたら閉じる（前面に置かないのでドロップを邪魔しない）
                            if showFoodShelf {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { closeFoodShelf() }
                            }

                            // 1) キャラクター
                            ZStack {
                                Rectangle()
                                    .fill(Color.black.opacity(0.001))
                                    .frame(width: characterWidth, height: characterWidth * 1.15)
                                    .offset(y: Layout.characterTopOffset)
                                    .zIndex(Layout.zCharacter)
                                    .highPriorityGesture(
                                        TapGesture().onEnded { triggerCharacterJump() }
                                    )
                                    // ✅ 追加：棚が開いている時は、キャラ周辺をタップしても閉じる（ドロップは妨げない）
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            if showFoodShelf { closeFoodShelf() }
                                        }
                                    )
                                    .onDrop(
                                        of: [UTType.plainText.identifier, UTType.text.identifier],
                                        isTargeted: $isDropTargeted
                                    ) { providers in
                                        guard let provider = providers.first else { return false }

                                        provider.loadItem(
                                            forTypeIdentifier: UTType.plainText.identifier,
                                            options: nil
                                        ) { item, _ in
                                            let id: String? = {
                                                if let s = item as? String { return s }
                                                if let data = item as? Data,
                                                   let s = String(data: data, encoding: .utf8) { return s }
                                                if let url = item as? URL { return url.absoluteString }
                                                return nil
                                            }()

                                            guard let foodId = id else { return }
                                            DispatchQueue.main.async {
                                                _ = handleFoodDrop(foodId: foodId, state: state)

                                                // ✅ 念のため：ドロップ処理後は表情をベースに戻す
                                                endFoodHoverIfNeeded()
                                            }
                                        }
                                        return true
                                    }

                                Image(characterAssetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: characterWidth)
                                    .offset(y: Layout.characterTopOffset)
                                    .allowsHitTesting(false)
                            }

                            // 2) 左上：メーター
                            VStack(alignment: .leading, spacing: Layout.meterStackSpacing) {
                                FriendshipMeter(
                                    value: displayedFriendship,
                                    maxValue: Double(AppState.friendshipMaxMeter),
                                    barWidth: Layout.barWidth,
                                    height: Layout.capsuleHeight,
                                    iconSize: Layout.iconHeartSize,
                                    redMinWidth: Layout.redMinWidth
                                )

                                VStack(alignment: .leading, spacing: Layout.satisfactionSpacingFromWallet) {
                                    WalletCapsule(
                                        walletKcal: displayedWalletKcal,
                                        barWidth: Layout.walletWidth,
                                        height: Layout.capsuleHeight,
                                        iconSize: Layout.iconCoinSize
                                    )

                                    SatisfactionMeter(
                                        level: displayedSatisfaction,
                                        maxLevel: Layout.satisfactionSegments,
                                        barWidth: Layout.satisfactionBarWidth,
                                        height: Layout.satisfactionBarHeight,
                                        gap: Layout.satisfactionSegmentGap,
                                        cornerRadius: Layout.satisfactionCornerRadius,
                                        iconAssetName: Layout.satisfactionIconAssetName,
                                        iconSize: Layout.satisfactionIconSize,
                                        iconSpacing: Layout.satisfactionIconSpacing
                                    )
                                }

                                Spacer()
                            }
                            .padding(.top, Layout.leftTopPaddingTop)
                            .padding(.leading, Layout.leftTopPaddingLeading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            // ✅ 追加：メーター周りをタップしたら閉じる
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    if showFoodShelf { closeFoodShelf() }
                                }
                            )

                            // 3) 右上：リング
                            KcalRing(
                                progress: displayedKcalProgress,
                                currentKcal: displayedTodayKcal,
                                goalKcal: state.dailyGoalKcal,
                                outerSize: Layout.kcalRingSizeOuter,
                                innerSize: Layout.kcalRingSizeInner
                            )
                            .padding(.top, Layout.kcalRingTop)
                            .padding(.trailing, Layout.kcalRingTrailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            // ✅ 追加：リング周りをタップしたら閉じる
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    if showFoodShelf { closeFoodShelf() }
                                }
                            )

                            // 4) 右側：縦ボタン
                            RightSideButtons(
                                state: state,
                                onCamera: { showCaptureModeDialog = true },
                                buttonSize: Layout.rightButtonSize,
                                spacing: Layout.rightButtonsSpacing
                            )
                            .padding(.top, Layout.rightButtonsTopOffset)
                            .padding(.trailing, Layout.rightButtonsTrailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            // ✅ 追加：ボタン領域をタップしても棚を閉じたい（押下の邪魔はしない）
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    if showFoodShelf { closeFoodShelf() }
                                }
                            )

                            // 4.5) ごはん棚
                            if showFoodShelf {
                                FoodShelfPanel(state: state)
                                    .padding(.horizontal, Layout.foodShelfHorizontalPadding)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    .padding(.bottom, Layout.bottomPadding + Layout.foodShelfBottomGapFromButtons)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                    .zIndex(Layout.zFoodShelf)
                            }

                            // 5) 下部：横ボタン群
                            TimelineView(.periodic(from: Date(), by: 60.0)) { timeline in
                                let now = timeline.date

                                let canFood = true // ✅ 満足度MAXでも棚は開ける
                                let canBath = isBathAvailablePure(now: now)
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
                                .onChange(of: timeline.date) { _, newDate in
                                    displayedSatisfaction = state.currentSatisfaction(now: newDate)
                                    state.ensureDailyResetIfNeeded(now: newDate)
                                    save()
                                }
                                .onAppear {
                                    displayedSatisfaction = state.currentSatisfaction(now: now)
                                    state.ensureDailyResetIfNeeded(now: now)
                                    save()
                                }
                            }
                            .padding(.bottom, Layout.bottomPadding)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            // ✅ 追加：下部ボタン周りタップでも棚を閉じる
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    if showFoodShelf { closeFoodShelf() }
                                }
                            )

                            // 6) “もじゃ” 演出（旧: チケット）
                            if showMojaOverlay {
                                ZStack {
                                    Color.black.opacity(0.001)
                                        .ignoresSafeArea()
                                        .onTapGesture { dismissMojaOverlay() }

                                    ZStack {
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

                                        // ✅ 報酬本体：もじゃ（asset: moja）
                                        Image("moja")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: min(geo.size.width * 0.7, Layout.rewardMaxWidth))
                                            .opacity(rewardOpacity)
                                            .scaleEffect(rewardScale)

                                        Image("get_text")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: min(geo.size.width * 0.62, Layout.getTextMaxWidth))
                                            .offset(x: Layout.getTextOffsetX, y: Layout.getTextOffsetY)
                                            .opacity(rewardOpacity)
                                            .scaleEffect(rewardScale)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .transition(.opacity)
                                .zIndex(Layout.zReward)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .confirmationDialog("撮影モードを選択", isPresented: $showCaptureModeDialog, titleVisibility: .visible) {
            Button("ARで撮影") { selectedCaptureMode = .ar }
            Button("通常撮影") { selectedCaptureMode = .plain }
            Button("キャンセル", role: .cancel) {}
        }
        .fullScreenCover(item: $selectedCaptureMode) { mode in
            CameraCaptureView(
                initialMode: mode,
                todaySteps: hk.todaySteps,
                todayActiveKcal: hk.todayActiveEnergyKcal,
                todayTotalKcal: hk.todayTotalEnergyKcal,
                plainBackgroundAssetName: Layout.homeBackgroundAssetName,
                characterAssetName: PetMaster.assetName(for: state.currentPetID) // ✅ 追加
            ) {
                selectedCaptureMode = nil
            } onCapture: { image in
                saveTodayPhoto(image, placeName: nil, latitude: nil, longitude: nil)
                selectedCaptureMode = nil
            } onCaptureWithPlace: { image, placeName, lat, lon in
                saveTodayPhoto(image, placeName: placeName, latitude: lat, longitude: lon)
                selectedCaptureMode = nil
            }
        }
        .task {
            state.ensureInitialPetsIfNeeded()

            // ✅ 追加：Home表示キャラを currentPetID に合わせる
            syncCharacterBaseFromState(force: true)

            if state.dailyGoalKcal > 0, didSetDailyGoalOnce == false {
                didSetDailyGoalOnce = true
            }

            todaySteps = state.cachedTodaySteps
            todayKcal = state.cachedTodayKcal

            displayedTodayKcal = todayKcal
            displayedWalletKcal = state.walletKcal
            displayedSatisfaction = state.currentSatisfaction(now: Date())

            displayedFriendship = Double(state.friendshipPoint)
            displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)

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

            // ✅ 追加：復帰時にも currentPetID を反映
            syncCharacterBaseFromState(force: true)

            todaySteps = state.cachedTodaySteps
            todayKcal = state.cachedTodayKcal

            displayedTodayKcal = todayKcal
            displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)

            displayedSatisfaction = state.currentSatisfaction(now: Date())

            handleDayRolloverIfNeeded(state: state)

            Task {
                await runSync(state: state)
                maybeSpawnToiletFlag(state: state)
                loadTodayPhoto()

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
                        displayedKcalProgress = calcKcalProgressRaw(
                            todayKcal: displayedTodayKcal,
                            goalKcal: state.dailyGoalKcal
                        )
                    }

                    showGoalSheet = false
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            isHomeVisible = true

            // ✅ 追加：表示開始時にも currentPetID を反映
            syncCharacterBaseFromState(force: true)

            startCharacterIdleLoopIfNeeded()

            withAnimation(.easeOut(duration: 0.25)) {
                displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
            }

            displayedSatisfaction = state.currentSatisfaction(now: Date())

            Task { await reconcileWalletDisplayIfNeeded(state: state) }
        }
        .onDisappear {
            isHomeVisible = false
            Haptics.stopRattle()

            stopCharacterIdleLoop()
            isCharacterActionRunning = false

            // ✅ 修正：purpor 固定に戻さず、ベースに戻す
            characterAssetName = currentBaseAssetName
        }
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
        // ✅ 追加：図鑑で「育成する」→ Homeに即反映
        .onChange(of: state.currentPetID) { _, _ in
            syncCharacterBaseFromState(force: true)
        }
        // ✅ 追加：ドラッグでキャラ上ホバー中（isDropTargeted）に表情を差し替え
        .onChange(of: isDropTargeted) { _, newValue in
            if newValue {
                beginFoodHover()
            } else {
                endFoodHoverIfNeeded()
            }
        }
        // ✅ 追加：ホバー中に満足度が変わったら即反映（MAX/非MAXの差し替え）
        .onChange(of: displayedSatisfaction) { _, _ in
            guard isFoodHoveringOverCharacter else { return }
            beginFoodHover()
        }
    }

    // MARK: - ✅ currentPetID → 表示キャラ反映
    private func syncCharacterBaseFromState(force: Bool) {
        // アクション中は差し替えるとチラつくので、強制時以外は避ける
        if !force {
            guard !isCharacterActionRunning else { return }
        }

        // ホバー中は “ホバー用アセット” が優先
        if isFoodHoveringOverCharacter {
            beginFoodHover()
            return
        }

        // 既存のアニメ系がpurpor前提なので、purpor以外は静止画運用
        characterAssetName = currentBaseAssetName
    }

    // MARK: - ✅ Food Hover（purpor_hungry / purpor_burp）
    private func beginFoodHover() {
        isFoodHoveringOverCharacter = true

        // purpor 以外は hover差し替え素材が無い想定なので、ベースのまま
        guard canPlayCharacterAnimation else {
            characterAssetName = currentBaseAssetName
            return
        }

        // アクション中は割り込みたくない（ただしホバー優先にしたい場合はここを外せる）
        guard !isCharacterActionRunning else { return }

        characterAssetName = isSatisfactionMax ? "purpor_burp" : "purpor_hungry"
    }

    private func endFoodHoverIfNeeded() {
        guard isFoodHoveringOverCharacter else { return }
        isFoodHoveringOverCharacter = false

        // アクション中は自然復帰に任せる（完了時に base に戻る）
        guard !isCharacterActionRunning else { return }

        characterAssetName = currentBaseAssetName
    }

    // MARK: - FoodShelf
    private func closeFoodShelf() {
        guard showFoodShelf else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            showFoodShelf = false
        }
    }

    // MARK: - Bath availability（純参照：body内で安全に使える）
    private func isBathAvailablePure(now: Date) -> Bool {
        guard let last = state.bathLastAt else { return true }
        return now.timeIntervalSince(last) >= (8 * 60 * 60)
    }

    // MARK: - Character animation
    private func startCharacterIdleLoopIfNeeded() {
        guard idleLoopTask == nil else { return }

        idleLoopTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)

            while !Task.isCancelled {
                if !isHomeVisible {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    continue
                }

                // ✅ 追加：ホバー中は差し替えを維持したいので、アイドル割り込みを止める
                if isFoodHoveringOverCharacter {
                    try? await Task.sleep(nanoseconds: 120_000_000)
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
                if isFoodHoveringOverCharacter { continue }
                if isCharacterActionRunning { continue }

                // ✅ 追加：purpor以外はまばたき素材が無い想定なのでスキップ
                if !canPlayCharacterAnimation {
                    await MainActor.run {
                        characterAssetName = currentBaseAssetName
                    }
                    continue
                }

                let doDouble = Double.random(in: 0...1) < doubleBlinkChance

                await playBlink()

                if doDouble {
                    let gap = Double.random(in: doubleBlinkGapRange)
                    try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))

                    if Task.isCancelled { break }
                    if !isHomeVisible { continue }
                    if isFoodHoveringOverCharacter { continue }
                    if isCharacterActionRunning { continue }

                    await playBlink()
                }
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

        // ✅ 追加：ホバー中はジャンプさせない（表情維持）
        guard !isFoodHoveringOverCharacter else { return }

        // ✅ 追加：purpor以外はジャンプ素材が無い想定なので何もしない
        guard canPlayCharacterAnimation else { return }

        Task { await playJump() }
    }

    private func playBlink() async {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }

        // ✅ 追加：ホバー中は差し替え優先
        guard !isFoodHoveringOverCharacter else { return }

        // ✅ 追加：purpor前提
        guard canPlayCharacterAnimation else {
            await MainActor.run { characterAssetName = currentBaseAssetName }
            return
        }

        await MainActor.run { characterAssetName = "purpor_idle_blink_0001" }
        try? await Task.sleep(nanoseconds: 70_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }
        if isFoodHoveringOverCharacter { return }

        await MainActor.run { characterAssetName = "purpor_idle_blink_0002" }
        try? await Task.sleep(nanoseconds: 60_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }
        if isFoodHoveringOverCharacter { return }

        await MainActor.run { characterAssetName = "purpor_idle_blink_0003" }
        try? await Task.sleep(nanoseconds: 70_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }
        if isFoodHoveringOverCharacter { return }

        await MainActor.run { characterAssetName = currentBaseAssetName }
    }

    private func playJump() async {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }

        // ✅ 追加：ホバー中は差し替え優先
        guard !isFoodHoveringOverCharacter else { return }

        // ✅ 追加：purpor前提
        guard canPlayCharacterAnimation else {
            await MainActor.run { characterAssetName = currentBaseAssetName }
            return
        }

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
            characterAssetName = currentBaseAssetName
            isCharacterActionRunning = false
        }

        // ✅ 追加：ジャンプ完了直後にホバー中なら、ホバー用表情へ戻す
        if isFoodHoveringOverCharacter {
            await MainActor.run { beginFoodHover() }
        }
    }

    // MARK: - Drag & Drop（ごはん）
    private func handleFoodDrop(foodId: String, state: AppState) -> Bool {
        defer {
            closeFoodShelf()
            endFoodHoverIfNeeded()
        }

        guard let food = FoodCatalog.byId(foodId) else {
            toast("ご飯が見つかりません")
            return false
        }

        let check = state.canFeedNow(now: Date())
        guard check.can else {
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

        let fed = state.feedOnce(now: Date())
        guard fed.didFeed else {
            toast(fed.reason ?? "今はご飯できません")
            return false
        }

        save()

        displayedSatisfaction = fed.after
        addFriendshipWithAnimation(points: 10, state: state)
        toast("\(food.name)をあげた！ +10")

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

            // ✅ MAX到達報酬：もじゃ演出
            triggerMojaOverlay()

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
    }

    private func triggerMojaOverlay() {
        showMojaOverlay = false
        rewardScale = 0.8
        rewardOpacity = 0.0
        getOpacity = 0.0
        getRotation = 0.0

        withAnimation(.easeOut(duration: 0.12)) {
            showMojaOverlay = true
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
            rewardScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.18)) {
            rewardOpacity = 1.0
            getOpacity = 1.0
        }

        withAnimation(.linear(duration: Layout.getRotationDuration).repeatForever(autoreverses: false)) {
            getRotation = 360
        }
    }

    private func dismissMojaOverlay() {
        withAnimation(.easeInOut(duration: 0.18)) {
            rewardOpacity = 0.0
            getOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.12)) {
                showMojaOverlay = false
            }
            rewardScale = 0.8
            getRotation = 0.0
        }
    }

    // MARK: - ✅ 今日の一枚（同日複数に対応）
    private func makeUniquePhotoFileName(dayKey: String, now: Date) -> String {
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        return "\(dayKey)_\(ms).jpg"
    }

    private func loadTodayPhoto() {
        let key = AppState.makeDayKey(Date())
        do {
            var descriptor = FetchDescriptor<TodayPhotoEntry>(
                predicate: #Predicate { $0.dayKey == key },
                sortBy: [SortDescriptor(\TodayPhotoEntry.date, order: .reverse)]
            )
            descriptor.fetchLimit = 1

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

    private func normalizePlaceName(_ placeName: String?) -> String? {
        guard let placeName else { return nil }
        let t = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func saveTodayPhoto(
        _ uiImage: UIImage,
        placeName: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        do {
            let key = AppState.makeDayKey(Date())
            let now = Date()

            let fileName = makeUniquePhotoFileName(dayKey: key, now: now)

            try TodayPhotoStorage.saveJPEG(uiImage, fileName: fileName, quality: 0.9)

            let created = TodayPhotoEntry(
                dayKey: key,
                date: now,
                fileName: fileName,
                placeName: normalizePlaceName(placeName),
                latitude: latitude,
                longitude: longitude
            )
            modelContext.insert(created)

            try modelContext.save()

            todayPhotoEntry = created
            todayPhotoImage = uiImage

            toast("今日の一枚を保存しました")
            Task { @MainActor in
                Haptics.rattle(duration: 0.18, style: .light)
            }
        } catch {
            print("❌ saveTodayPhoto failed:", error)
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

        if showFoodShelf {
            closeFoodShelf()
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            showFoodShelf = true
        }
    }

    private func onTapBath(state: AppState) {
        let now = Date()

        state.ensureDailyResetIfNeeded(now: now)

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
        do {
            try modelContext.save()
        } catch {
            print("❌ modelContext.save() failed:", error)
        }
    }

    private func handleDayRolloverIfNeeded(state: AppState) {
        let now = Date()
        let todayKey = AppState.makeDayKey(now)
        guard state.lastDayKey == todayKey else {
            state.ensureDailyResetIfNeeded(now: now)

            state.lastSyncedAt = Calendar.current.startOfDay(for: now)

            // ✅ 卵は廃止のため、eggAdUsedToday などは触らない

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
                displayedKcalProgress = calcKcalProgressRaw(
                    todayKcal: displayedTodayKcal,
                    goalKcal: state.dailyGoalKcal
                )
            }
        }
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

// MARK: - UI Parts

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

                Text("\(walletKcal)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
    }
}

// ✅ 満足度メーター（3区切り）＋ 左アイコン(food_Icon)
private struct SatisfactionMeter: View {
    let level: Int
    let maxLevel: Int
    let barWidth: CGFloat
    let height: CGFloat
    let gap: CGFloat
    let cornerRadius: CGFloat

    let iconAssetName: String
    let iconSize: CGFloat
    let iconSpacing: CGFloat

    private var clamped: Int { min(max(0, level), maxLevel) }

    var body: some View {
        let segments = max(1, maxLevel)
        let totalGap = gap * CGFloat(max(0, segments - 1))
        let segWidth = (barWidth - totalGap) / CGFloat(segments)

        HStack(spacing: iconSpacing) {
            Image(iconAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            HStack(spacing: gap) {
                ForEach(0..<segments, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(idx < clamped ? Color.green.opacity(0.95) : Color.black.opacity(0.55))
                        .frame(width: segWidth, height: height)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                        )
                }
            }
            .frame(width: barWidth, height: height, alignment: .leading)
        }
    }
}

private struct KcalRing: View {
    let progress: Double
    let currentKcal: Int
    let goalKcal: Int

    let outerSize: CGFloat
    let innerSize: CGFloat

    private var goalText: String { goalKcal > 0 ? "\(goalKcal)" : "—" }

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

            // ✅ 追加：思い出ボタンと図鑑ボタンの間に “もじゃ” ボタン
            NavigationLink { MojaView(state: state) } label: {
                Image("moja")
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

private struct FoodShelfPanel: View {
    let state: AppState

    @State private var currentPage: Int = 0

    private var ownedFoods: [FoodCatalog.FoodItem] {
        FoodCatalog.all.filter { state.foodCount(foodId: $0.id) > 0 }
    }

    private var pages: [[FoodCatalog.FoodItem]] {
        chunked(ownedFoods, size: 3)
    }

    private var pageCount: Int { pages.count }
    private var canGoPrev: Bool { currentPage > 0 }
    private var canGoNext: Bool { currentPage + 1 < pageCount }

    var body: some View {
        ZStack {
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
                ZStack {
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { idx, foods in
                            HStack(spacing: 12) {
                                ForEach(foods) { food in
                                    FoodItemCell(
                                        food: food,
                                        count: state.foodCount(foodId: food.id)
                                    )
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: pageCount) { _, _ in
                        if currentPage >= pageCount {
                            currentPage = max(0, pageCount - 1)
                        }
                    }

                    HStack {
                        arrowButton(systemName: "chevron.left", enabled: canGoPrev) {
                            guard canGoPrev else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                currentPage -= 1
                            }
                        }

                        Spacer()

                        arrowButton(systemName: "chevron.right", enabled: canGoNext) {
                            guard canGoNext else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                currentPage += 1
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
        .frame(height: HomeView.Layout.foodShelfHeight)
    }

    private func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0, !items.isEmpty else { return [] }
        var result: [[T]] = []
        var i = 0
        while i < items.count {
            let end = min(i + size, items.count)
            result.append(Array(items[i..<end]))
            i = end
        }
        return result
    }

    @ViewBuilder
    private func arrowButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(enabled ? Color.black.opacity(0.85) : Color.gray.opacity(0.55))
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(enabled ? 0.72 : 0.35))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.black.opacity(enabled ? 0.28 : 0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.85)
        .contentShape(Circle())
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
