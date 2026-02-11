//
//  ShopView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import SwiftUI
import SwiftData
import UIKit

struct ShopView: View {
    @Environment(\.modelContext) private var modelContext

    // ✅ Rootから渡された“同一のAppState”を使う
    let state: AppState

    @StateObject private var viewModel = ShopViewModel()

    var body: some View {
        ZStack {
            // ✅ Homeと同系色（不要なら Color.clear でOK）
            Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    // 所持kcal
                    WalletSummaryCard(
                        walletKcal: viewModel.displayedWalletKcal,     // ✅ 表示用（カウントダウン）
                        pendingKcal: state.pendingKcal
                    )

                    // 卵
                    EggCard(
                        eggOwned: state.eggOwned,
                        hatchAt: state.eggHatchAt,
                        cardCount: state.friendshipCardCount,
                        eggAdUsedToday: state.eggAdUsedToday,
                        onBuyEgg: { viewModel.buyEgg(state: state); save() },
                        onInstantHatchAd: { viewModel.instantHatchByAd(state: state); save() },
                        onHatch: { viewModel.hatchEgg(state: state); save() }
                    )

                    // ✅ デイリーショップ（FoodCatalog から6品抽選）
                    DailyShopCard(
                        items: viewModel.decodeShopItems(from: state) ?? [],
                        rewardResetsToday: state.shopRewardResetsToday,
                        maxRewardResetsPerDay: 2,
                        onBuy: { item in
                            viewModel.buyFood(itemID: item.id, state: state); save()
                        },
                        onRewardReset: {
                            viewModel.rewardResetShopByAd(state: state, maxPerDay: 2); save()
                        }
                    )
                }
                .padding()
            }
        }
        .navigationTitle("ショップ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.onAppear(state: state)
            save()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.onAppear(state: state)
            save()
        }
        .alert("孵化", isPresented: $viewModel.showHatchAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.hatchMessage)
        }
        .overlay(alignment: .bottom) {
            if viewModel.showToast, let toastMessage = viewModel.toastMessage {
                ToastView(message: toastMessage)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func save() {
        do { try modelContext.save() } catch { }
    }
}

// MARK: - Wallet summary

private struct WalletSummaryCard: View {
    let walletKcal: Int
    let pendingKcal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("所持kcal（通貨）").font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("所持").font(.caption).foregroundStyle(.secondary)
                    Text("\(walletKcal) kcal")
                        .font(.title2).bold()
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("未反映").font(.caption).foregroundStyle(.secondary)
                    Text("\(pendingKcal) kcal").font(.title3).bold()
                }
            }

            Text("※ 通貨kcal = アクティブ + 安静時（1日の合計）")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("※ 料理の価格＝kcal（所持から消費）")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Daily shop UI

private struct DailyShopCard: View {
    let items: [ShopFoodItem]
    let rewardResetsToday: Int
    let maxRewardResetsPerDay: Int

    let onBuy: (ShopFoodItem) -> Void
    let onRewardReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("デイリーショップ").font(.headline)
                Spacer()
                Text("リセット \(rewardResetsToday)/\(maxRewardResetsPerDay)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("毎日 00:00 更新 / 6品 / 在庫 各1個")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if items.isEmpty {
                Text("ラインナップを生成中...")
                    .font(.title3).bold()
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.headline)
                                Text("\(item.kcal) kcal")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.stock > 0 ? "在庫1" : "売切")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())

                            Button("購入") { onBuy(item) }
                                .buttonStyle(.borderedProminent)
                                .disabled(item.stock == 0)
                                .opacity(item.stock == 0 ? 0.6 : 1.0)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            HStack(spacing: 10) {
                Button("広告でリセット（ダミー）") { onRewardReset() }
                    .buttonStyle(.bordered)
                    .disabled(rewardResetsToday >= maxRewardResetsPerDay)
            }

            Text("※ リセットで「再抽選＋全在庫1に戻す」")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Egg UI

private struct EggCard: View {
    let eggOwned: Bool
    let hatchAt: Date?
    let cardCount: Int
    let eggAdUsedToday: Bool

    let onBuyEgg: () -> Void
    let onInstantHatchAd: () -> Void
    let onHatch: () -> Void

    private var canBuy: Bool {
        cardCount >= 1 && !eggOwned
    }

    private var isHatchReady: Bool {
        guard eggOwned, let hatchAt else { return false }
        return Date() >= hatchAt
    }

    private var remainingText: String {
        guard eggOwned, let hatchAt else { return "-" }
        let sec = max(0, Int(hatchAt.timeIntervalSinceNow))
        let h = sec / 3600
        let m = (sec % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("卵").font(.headline)
                Spacer()
                Text("なかよしカード \(cardCount)枚")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !eggOwned {
                Text("カード1枚で卵を購入できます（同時に1個まで）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("卵を購入（カード1枚）") { onBuyEgg() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canBuy)

            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isHatchReady ? "孵化できます！" : "孵化まで残り \(remainingText)")
                            .font(.title3).bold()

                        Text("孵化：購入から6時間後")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    Button("孵化する") { onHatch() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isHatchReady)

                    Button("今すぐ孵化（広告）") { onInstantHatchAd() }
                        .buttonStyle(.bordered)
                        .disabled(eggAdUsedToday || isHatchReady)
                }

                if eggAdUsedToday {
                    Text("※ 本日の即孵化（広告）は使用済み")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Toast view

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
