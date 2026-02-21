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
/// - 今回の仕様：moja を消費して「もじゃをまとめる」→ 6時間カウント → 0で新キャラ獲得（ランダム）
/// - デモ用：moja 1個消費で開始（将来調整）
/// - 進行状態は UserDefaults(AppStorage相当) に保存（アプリを閉じても継続）
///
/// ✅ MVVM化：状態/ロジックは MojaViewModel に寄せる（既存UIはなるべく維持）
struct MojaView: View {
    let state: AppState

    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = MojaViewModel()

    // 1秒ごとに更新
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.05).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header

                    fusionCard

                    statusCards

                    roadmapCard

                    Spacer(minLength: 24)
                }
                .padding()
            }

            // ✅ 画面中央トースト（VMの状態をそのまま反映）
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
        }
        .navigationTitle("もじゃ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 日跨ぎ系のズレを避ける（他画面と同じノリ）
            state.ensureDailyResetIfNeeded(now: Date())
            // 初期キャラだけは担保
            state.ensureInitialPetsIfNeeded()

            // デモ用の初期配布など
            viewModel.onAppearPrepareDemoIfNeeded()

            save()
        }
        .onReceive(tick) { _ in
            // fusion中のフレーム切り替え＆完了判定
            viewModel.tick(now: Date(), state: state)
        }
    }

    // MARK: - UI

    private var header: some View {
        VStack(spacing: 10) {
            Image("moja")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            Text("もじゃ")
                .font(.title2.bold())

            Text("mojaをまとめて、新しいキャラクターを手に入れよう。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
        .padding(.top, 6)
    }

    /// ✅ 仕様に合わせた「まとめる」カード
    private var fusionCard: some View {
        InfoCard(title: "もじゃ合体") {
            VStack(spacing: 12) {

                // ① moja_fusion* 表示（fusion中はA→B→C→Dを1秒ごとに切り替え）
                Image(viewModel.currentFusionAssetName())
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                // 所持表示
                HStack {
                    Label("所持moja", systemImage: "sparkles")
                    Spacer()
                    Text("\(viewModel.mojaCount)")
                        .monospacedDigit()
                        .font(.headline)
                }

                // ② 所用時間（6時間スタート）
                HStack {
                    Label("まとまるまで", systemImage: "clock")
                    Spacer()
                    Text(viewModel.fusionIsRunning ? viewModel.formattedRemaining(now: Date()) : "06:00:00")
                        .monospacedDigit()
                        .font(.headline)
                }
                .foregroundStyle(viewModel.fusionIsRunning ? .primary : .secondary)

                // ③ ボタン
                if viewModel.fusionIsRunning {
                    Button {
                        // デモ用：広告視聴の代わりに 1時間短縮（将来ここを広告連携に差し替え）
                        viewModel.applyAdReduction(seconds: 60 * 60, now: Date(), state: state)
                        save()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.rectangle.fill")
                            Text("広告視聴で時間を短縮")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        viewModel.startFusion(now: Date())
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
                    .disabled(viewModel.mojaCount < viewModel.fusionCost)
                    .opacity(viewModel.mojaCount < viewModel.fusionCost ? 0.5 : 1.0)

                    if viewModel.mojaCount < viewModel.fusionCost {
                        Text("※ mojaが足りません（必要: \(viewModel.fusionCost)）")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var statusCards: some View {
        VStack(spacing: 12) {

            // ✅ 今あるデータで「状態が見える」カード（後で差し替えやすい）
            InfoCard(title: "現在の状態") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("所持kcal", systemImage: "flame.fill")
                        Spacer()
                        Text("\(state.walletKcal) kcal")
                            .monospacedDigit()
                            .font(.headline)
                    }

                    HStack {
                        Label("未反映kcal", systemImage: "hourglass")
                        Spacer()
                        Text("\(state.pendingKcal) kcal")
                            .monospacedDigit()
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider().opacity(0.35)

                    HStack {
                        Label("なかよし", systemImage: "heart.fill")
                        Spacer()
                        Text("\(state.friendshipPoint)/\(AppState.friendshipMaxMeter)")
                            .monospacedDigit()
                            .font(.headline)
                    }

                    HStack {
                        Label("なかよしカード", systemImage: "ticket.fill")
                        Spacer()
                        Text("\(state.friendshipCardCount) 枚")
                            .monospacedDigit()
                            .font(.headline)
                    }

                    Divider().opacity(0.35)

                    HStack {
                        Label("満足度", systemImage: "fork.knife")
                        Spacer()
                        Text("\(state.currentSatisfaction(now: Date())) / 3")
                            .monospacedDigit()
                            .font(.headline)
                    }

                    HStack {
                        Label("育て中キャラ", systemImage: "pawprint.fill")
                        Spacer()
                        Text(state.currentPetID)
                            .monospacedDigit()
                            .font(.subheadline)
                    }

                    HStack {
                        Label("所持キャラ数", systemImage: "person.3.fill")
                        Spacer()
                        Text("\(state.ownedPetIDs().count)")
                            .monospacedDigit()
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private var roadmapCard: some View {
        InfoCard(title: "ここに載せる予定の機能") {
            VStack(alignment: .leading, spacing: 8) {
                bullet("もじゃ所持数（友達ゲージMAX報酬）")
                bullet("もじゃの交換：もじゃ → 卵 / ごはん / アイテム")
                bullet("もじゃの合体：一定数で新キャラ解放")
                bullet("もじゃ獲得ログ / 演出の履歴")
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.headline)
                .padding(.top, 1)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Save

    private func save() {
        do { try modelContext.save() } catch { }
    }
}

// MARK: - Reusable card

private struct InfoCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
