//
//  MojaView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/21.
//

import SwiftUI
import SwiftData

struct MojaView: View {
    let state: AppState

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false

    @StateObject private var viewModel = MojaViewModel()

    // ✅ リワード広告（Reward_moja）
    @StateObject private var rewardedAd = RewardedAdManager(adUnitID: AdUnitID.rewardMoja)

    // ✅ 「いますぐ確認」→ 図鑑へ遷移
    @State private var navigateToZukan: Bool = false

    /// ✅ 未開始時の押下可否
    private var canStartFusion: Bool {
        viewModel.canStartFusion(state: state)
    }

    /// ✅ ボタン無効状態を集約
    private var isMainButtonDisabled: Bool {
        if viewModel.fusionIsReadyToClaim {
            return false
        }

        if viewModel.fusionIsRunning {
            return isDeveloperMode ? false : !rewardedAd.isReady
        }

        return !canStartFusion
    }

    /// ✅ ボタンの見た目用 opacity
    private var mainButtonOpacity: Double {
        if viewModel.fusionIsRunning && !(isDeveloperMode || rewardedAd.isReady) {
            return 0.6
        }

        if !viewModel.fusionIsRunning && !viewModel.fusionIsReadyToClaim && !canStartFusion {
            return 0.5
        }

        return 1.0
    }

    var body: some View {
        ZStack {
            // ✅ 元の背景（レイアウト維持のため残す）
            Color.black.opacity(0.05).ignoresSafeArea()

            VStack(spacing: 14) {

                // ① もじゃの画像（✅ 0到達後は CalPet_secret 固定）
                Image(viewModel.currentFusionAssetName())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)

                // ② まとまるまで hh:mm:ss
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    HStack(spacing: 8) {
                        Text("まとまるまで")
                            .font(.headline)

                        Text(viewModel.formattedDisplayTime(now: context.date))
                            .monospacedDigit()
                            .font(.headline)
                    }
                    .padding(.top, 2)
                }

                // ③ ボタン
                Button {
                    bgmManager.playSE(.push)

                    if viewModel.fusionIsReadyToClaim {
                        // ✅ 新キャラ獲得 + 状態リセット + ポップアップ表示
                        viewModel.claimNewPet(state: state)
                        bgmManager.playSE(.crap)
                        save()
                        return
                    }

                    if viewModel.fusionIsRunning {
                        // ✅ 仕様：タイマー動作中は「広告視聴で3時間短縮」
                        if isDeveloperMode {
                            viewModel.applyAdReduction(
                                seconds: 3 * 60 * 60,
                                now: Date(),
                                state: state
                            )
                            save()
                            return
                        }

                        if rewardedAd.isReady {
                            rewardedAd.show {
                                // ✅ 報酬：3時間短縮
                                viewModel.applyAdReduction(
                                    seconds: 3 * 60 * 60,
                                    now: Date(),
                                    state: state
                                )
                                save()
                            }
                        } else {
                            // 未ロード時は再ロード（押下体験は保ちつつ、暴発はしない）
                            rewardedAd.load()
                        }
                        return
                    }

                    // ✅ まとめ開始（全キャラ所持時はトースト表示のみ）
                    viewModel.startFusion(now: Date(), state: state)
                    save()

                    // 開始後、念のため次の広告もロードしておく
                    rewardedAd.load()

                } label: {
                    HStack(spacing: 8) {
                        if viewModel.fusionIsReadyToClaim {
                            Text("新しいカルペットをGET")
                                .font(.headline)
                        } else if viewModel.fusionIsRunning {
                            Text(isDeveloperMode ? "3時間短縮する" : "広告視聴で3時間短縮")
                                .font(.headline)
                        } else {
                            Image("moja")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)

                            Text("をまとめる（x5 消費）")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 18)
                .disabled(isMainButtonDisabled)
                .opacity(mainButtonOpacity)

                // ④ 所持している (moja)
                HStack(spacing: 6) {
                    Text("所持している")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image("moja")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)

                    Text("\(viewModel.mojaCount)")
                        .monospacedDigit()
                        .font(.headline)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // ✅ 獲得ポップアップ（中央）
            if viewModel.showRewardPopup, let petID = viewModel.rewardedPetID {
                RewardPopup(
                    petAssetName: PetMaster.assetName(for: petID),
                    onClose: {
                        bgmManager.playSE(.push)
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.showRewardPopup = false
                        }
                    },
                    onGoNow: {
                        bgmManager.playSE(.push)
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.showRewardPopup = false
                        }
                        navigateToZukan = true
                    }
                )
                .transition(.opacity)
            }

            // 中央トースト
            if viewModel.showCenterToast, let msg = viewModel.centerToastMessage {
                VStack {
                    Text(msg)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(radius: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .background(
            ZStack {
                Image("Moja_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.25)
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("もじゃ合わせ")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToZukan) {
            ZukanView()
        }
        .onAppear {
            state.ensureDailyResetIfNeeded(now: Date())
            state.ensureInitialPetsIfNeeded()

            // ✅ AppState を正本として mojaCount を同期
            viewModel.onAppearPrepareDemoIfNeeded(state: state)

            save()

            // ✅ リワード広告を事前ロード
            rewardedAd.load()
        }
        .onChange(of: state.mojaCount) { _, _ in
            // ✅ HomeView 側で増えた moja をこの画面にも即反映
            viewModel.syncMojaCount(from: state)
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch { }
    }
}

private struct RewardPopup: View {
    let petAssetName: String
    let onClose: () -> Void
    let onGoNow: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 14) {
                Image(petAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)

                HStack(spacing: 12) {
                    Button("とじる") {
                        onClose()
                    }
                    .buttonStyle(.bordered)

                    Button("いますぐ確認") {
                        onGoNow()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(radius: 12)
            .padding(.horizontal, 22)
        }
    }
}
