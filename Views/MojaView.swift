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
    @StateObject private var viewModel = MojaViewModel()

    // ✅ 「いますぐ確認」→ 図鑑へ遷移
    @State private var navigateToZukan: Bool = false

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

                // ③ ボタン（✅ 完了後は「新しいカルペットをGET」に変更）
                Button {
                    if viewModel.fusionIsReadyToClaim {
                        // ✅ 新キャラ獲得 + 状態リセット + ポップアップ表示
                        viewModel.claimNewPet(state: state)
                        save()
                    } else {
                        // ✅ まとめ開始
                        viewModel.startFusion(now: Date())
                        save()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.fusionIsReadyToClaim {
                            Text("新しいカルペットをGET")
                                .font(.headline)
                        } else {
                            Image("moja")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)

                            Text("をまとめる")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 18)
                .disabled(viewModel.isActionButtonDisabled)
                .opacity(viewModel.isActionButtonDisabled ? 0.5 : 1.0)

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
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.showRewardPopup = false
                        }
                    },
                    onGoNow: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.showRewardPopup = false
                        }
                        // ✅ 図鑑へ
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(radius: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }

            // ✅ 画面遷移用（隠し NavigationLink）
            NavigationLink(isActive: $navigateToZukan) {
                ZukanView()
            } label: {
                EmptyView()
            }
            .hidden()
        }
        // ✅ 背景画像は「後ろに描画」するだけ（中身のレイアウトに干渉しにくい）
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

        .onAppear {
            state.ensureDailyResetIfNeeded(now: Date())
            state.ensureInitialPetsIfNeeded()
            viewModel.onAppearPrepareDemoIfNeeded()
            save()
        }
    }

    private func save() {
        do { try modelContext.save() } catch { }
    }
}

private struct RewardPopup: View {
    let petAssetName: String
    let onClose: () -> Void
    let onGoNow: () -> Void

    var body: some View {
        ZStack {
            // 背景暗幕
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    // 画面外タップで閉じてもいいが、仕様にないので無効化したい場合は削除OK
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
