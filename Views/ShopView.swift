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
    let state: AppState
    @StateObject private var viewModel = ShopViewModel()

    // ✅ 購入ポップアップ制御
    @State private var popup: PurchasePopupState = .none

    // ✅ 不足表示の自動消し
    @State private var dismissInsufficientTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // ✅ 背景画像を見せたいので、ベタ塗りをやめる（レイアウトは変わらない）
            Color.clear.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // ✅ 仕様変更：画面上部の所持カロリー表示は不要（削除）

                    DailyShopCard(
                        items: viewModel.decodeShopItems(from: state) ?? [],
                        rewardResetsToday: state.shopRewardResetsToday,
                        maxRewardResetsPerDay: 2,
                        ownedCountProvider: { itemID in
                            viewModel.ownedCount(for: itemID, state: state)
                        },
                        onBuyTap: { item in
                            onTapBuy(item)
                        },
                        onRewardReset: {
                            viewModel.rewardResetShopByAd(state: state, maxPerDay: 2); save()
                        }
                    )
                }
                .padding()
                .padding(.top, 6) // ✅ 固定ヘッダーとの見た目調整（必要なら微調整）
            }
            // ✅ 仕様変更：画面上部に固定（スクロールしても見える）
            .safeAreaInset(edge: .top) {
                ShopWalletHeader(walletKcal: viewModel.displayedWalletKcal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(.ultraThinMaterial)
            }

            // ✅ 仕様変更：購入ポップアップ（中央表示）
            if popup.isPresented {
                PurchasePopupOverlay(
                    popup: $popup,
                    onConfirmBuy: { item in
                        viewModel.buyFood(itemID: item.id, state: state); save()
                        popup = .none
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .background(
            ZStack {
                Image("Shop_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.25)
                    .ignoresSafeArea()
            }
        )
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
        .overlay(alignment: .bottom) {
            if viewModel.showToast, let toastMessage = viewModel.toastMessage {
                ToastView(message: toastMessage)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onDisappear {
            dismissInsufficientTask?.cancel()
            dismissInsufficientTask = nil
        }
    }

    private func onTapBuy(_ item: ShopFoodItem) {
        // ✅ 売り切れは従来通り（保険）
        guard item.stock > 0 else { return }

        // ✅ 所持不足 → 中央に文字表示
        guard state.walletKcal >= item.kcal else {
            dismissInsufficientTask?.cancel()
            popup = .insufficient

            // ✅ 少しだけ見せて自動で消す（文字だけ要件）
            dismissInsufficientTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if case .insufficient = popup {
                    popup = .none
                }
            }

            Haptics.rattle(duration: 0.12, style: .light)
            return
        }

        // ✅ 購入確認ポップアップ
        dismissInsufficientTask?.cancel()
        dismissInsufficientTask = nil
        popup = .confirm(item)
        Haptics.tap(style: .light)
    }

    private func save() {
        do { try modelContext.save() } catch { }
    }
}

// MARK: - Popup state

private enum PurchasePopupState: Equatable {
    case none
    case insufficient
    case confirm(ShopFoodItem)

    var isPresented: Bool {
        switch self {
        case .none: return false
        default: return true
        }
    }
}

// MARK: - Fixed wallet header（HomeViewの通貨表示と同系）

private struct ShopWalletHeader: View {
    let walletKcal: Int

    var body: some View {
        HStack(spacing: 12) {
            Image("coin_Icon")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)

            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 34)

                Text("\(walletKcal)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 18)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Popup overlay

private struct PurchasePopupOverlay: View {
    @Binding var popup: PurchasePopupState
    let onConfirmBuy: (ShopFoodItem) -> Void

    var body: some View {
        ZStack {
            // 背景（タップで閉じる）
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { popup = .none }

            switch popup {
            case .none:
                EmptyView()

            case .insufficient:
                // ✅ 仕様：不足時は文字のみ
                Text("所持Kcalが不足しています")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .onTapGesture { popup = .none }

            case .confirm(let item):
                VStack(spacing: 14) {
                    // ✅ 仕様：画像不要、文字は大きめ
                    Text("\(item.name) を購入しますか？")
                        .font(.system(size: 18, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        Button("キャンセル") {
                            popup = .none
                            Haptics.tap(style: .light)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.85))

                        Button("購入") {
                            onConfirmBuy(item)
                            Haptics.tap(style: .medium)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(18)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 28)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: popup.isPresented)
    }
}

// MARK: - Daily shop UI

private struct DailyShopCard: View {
    let items: [ShopFoodItem]
    let rewardResetsToday: Int
    let maxRewardResetsPerDay: Int

    // ✅ 追加：所持数を外から注入（ViewModelやStateを直接持たない）
    let ownedCountProvider: (String) -> Int

    // ✅ 仕様変更：購入タップはポップアップ経由に
    let onBuyTap: (ShopFoodItem) -> Void
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

            // ✅ 表示文言としての「在庫」はやめる（所持数が主役になるため）
            Text("毎日 00:00 更新 / 6品")
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

                            // ✅ 仕様変更：商品名の先頭に各商品のアセット画像
                            let asset = FoodCatalog.byId(item.id)?.assetName
                            if let asset {
                                Image(asset)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 34, height: 34)
                                    .padding(6)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.headline)
                                Text("\(item.kcal) kcal")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // ✅ 仕様変更：在庫表示 → 所持数表示
                            // - 売切/購入可否は stock で管理（従来通り）
                            // - 表示は ownedCount（ユーザー所持数）
                            let owned = ownedCountProvider(item.id)
                            Text("所持\(owned)")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())

                            Button("購入") { onBuyTap(item) }
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
