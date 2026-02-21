//
//  MojaView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/21.
//

import SwiftUI
import SwiftData
import Combine

/// ✅ HomeView から遷移する “もじゃ” 画面（本体）
/// - 仕様：もじゃをまとめる → カウントダウン → 0で完了（ロジックは既存VMを利用）
/// - 画面要素：仕様記載のもの以外は削除
struct MojaView: View {
    let state: AppState

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MojaViewModel()

    // 1秒ごとに更新
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // ✅ 画像切り替え用（ボタン押下後、1秒毎に切り替え）
    @State private var fusionAssetIndex: Int = 0

    private let fusionAssets: [String] = [
        "moja",
        "moja_fusionA",
        "moja_fusionB",
        "moja_fusionC"
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.05).ignoresSafeArea()

            VStack(spacing: 14) {

                // ① 画面タイトル
                Text("もじゃ合わせ")
                    .font(.title2.bold())
                    .padding(.top, 12)

                // ② もじゃの画像（ボタン押下後は1秒毎に切替）
                Image(currentMojaAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)

                // ③ まとまるまで hh:mm:ss
                HStack(spacing: 8) {
                    Text("まとまるまで")
                        .font(.headline)
                    Text(viewModel.fusionIsRunning ? viewModel.formattedRemaining(now: Date()) : "06:00:00")
                        .monospacedDigit()
                        .font(.headline)
                }
                .padding(.top, 2)

                // ④ "もじゃをまとめる"ボタン（挙動は現状のまま startFusion を呼ぶ）
                Button {
                    viewModel.startFusion(now: Date())
                    // ✅ ボタン押下時は moja から開始
                    fusionAssetIndex = 0
                    save()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.merge")
                        Text("もじゃをまとめる")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 18)
                .disabled(viewModel.fusionIsRunning || viewModel.mojaCount < viewModel.fusionCost)
                .opacity((viewModel.fusionIsRunning || viewModel.mojaCount < viewModel.fusionCost) ? 0.5 : 1.0)

                // ⑤ 現在所持しているもじゃの数表示
                HStack(spacing: 8) {
                    Text("所持もじゃ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.mojaCount)")
                        .monospacedDigit()
                        .font(.headline)
                }
                .padding(.top, 4)

                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .navigationTitle("もじゃ合わせ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            state.ensureDailyResetIfNeeded(now: Date())
            state.ensureInitialPetsIfNeeded()

            // デモ用の初期配布など（既存挙動維持）
            viewModel.onAppearPrepareDemoIfNeeded()

            fusionAssetIndex = 0
            save()
        }
        .onReceive(tick) { _ in
            // ✅ 既存の完了判定などはVMに任せる
            viewModel.tick(now: Date(), state: state)

            // ✅ fusion中のみ 1秒毎に切り替え（仕様の見た目）
            if viewModel.fusionIsRunning {
                fusionAssetIndex = (fusionAssetIndex + 1) % fusionAssets.count
            } else {
                // 終了したら moja に戻す
                fusionAssetIndex = 0
            }
        }
    }

    private var currentMojaAssetName: String {
        // fusion中は 1秒毎に切替、非fusion時は常に moja
        guard viewModel.fusionIsRunning else { return "moja" }
        return fusionAssets[fusionAssetIndex]
    }

    // MARK: - Save

    private func save() {
        do { try modelContext.save() } catch { }
    }
}
