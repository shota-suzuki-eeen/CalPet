//
//  ShopView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import SwiftUI
import SwiftData
import UIKit

// ✅ デイリーショップ用：保存する形（id は FoodCatalog.FoodItem.id）
fileprivate struct ShopFoodItem: Codable, Identifiable, Equatable {
    let id: String          // FoodCatalog.FoodItem.id
    let name: String
    let kcal: Int           // = price（通貨kcal）
    var stock: Int          // 0 or 1（MVP）
}

struct ShopView: View {
    @Environment(\.modelContext) private var modelContext

    // ✅ Rootから渡された“同一のAppState”を使う
    let state: AppState

    @State private var showHatchAlert = false
    @State private var hatchMessage = ""

    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    // ✅ ショップ内表示用（購入で減る時にカウントダウンさせる：ハプティクスなし）
    @State private var displayedWalletKcal: Int = 0

    var body: some View {
        ZStack {
            // ✅ Homeと同系色（不要なら Color.clear でOK）
            Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    // 所持kcal
                    WalletSummaryCard(
                        walletKcal: displayedWalletKcal,     // ✅ 表示用（カウントダウン）
                        pendingKcal: state.pendingKcal
                    )

                    // 卵
                    EggCard(
                        eggOwned: state.eggOwned,
                        hatchAt: state.eggHatchAt,
                        cardCount: state.friendshipCardCount,
                        eggAdUsedToday: state.eggAdUsedToday,
                        onBuyEgg: { buyEgg(state: state) },
                        onInstantHatchAd: { instantHatchByAd(state: state) },
                        onHatch: { hatchEgg(state: state) }
                    )

                    // ✅ デイリーショップ（FoodCatalog から6品抽選）
                    DailyShopCard(
                        items: decodeShopItems(from: state) ?? [],
                        rewardResetsToday: state.shopRewardResetsToday,
                        maxRewardResetsPerDay: 2,
                        onBuy: { item in
                            buyFood(itemID: item.id, state: state)
                        },
                        onRewardReset: {
                            rewardResetShopByAd(state: state, maxPerDay: 2)
                        }
                    )
                }
                .padding()
            }
        }
        .navigationTitle("ショップ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            state.ensureInitialPetsIfNeeded()

            handleDayRolloverIfNeeded(state: state)
            ensureDailyShopIfNeeded(state: state)

            // ✅ pending → wallet 反映（Homeを経由しない/演出途中でも購入できるように）
            applyPendingToWalletIfNeeded(state: state)

            // ✅ 初期表示
            displayedWalletKcal = state.walletKcal
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            state.ensureInitialPetsIfNeeded()

            handleDayRolloverIfNeeded(state: state)
            ensureDailyShopIfNeeded(state: state)

            // ✅ pending → wallet 反映
            applyPendingToWalletIfNeeded(state: state)

            // ✅ 復帰時は即追従（ショップ内は演出不要でもOK）
            displayedWalletKcal = state.walletKcal
        }
        .alert("孵化", isPresented: $showHatchAlert) {
            Button("OK") { }
        } message: {
            Text(hatchMessage)
        }
        .overlay(alignment: .bottom) {
            if showToast, let toastMessage {
                ToastView(message: toastMessage)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - pending → wallet（ショップ側セーフティ）

    /// Homeのgain演出とは別に、ショップに来た時点で pending が残っていれば wallet に反映して購入できる状態にする
    private func applyPendingToWalletIfNeeded(state: AppState) {
        guard state.pendingKcal > 0 else { return }
        let add = max(0, state.pendingKcal)
        guard add > 0 else { return }

        state.walletKcal += add
        state.pendingKcal = 0
        save()
    }

    // MARK: - Daily shop data（保存用）

    private func encodeShopItems(_ items: [ShopFoodItem]) -> Data? {
        try? JSONEncoder().encode(items)
    }

    private func decodeShopItems(from state: AppState) -> [ShopFoodItem]? {
        guard let data = state.shopItemsData else { return nil }
        return try? JSONDecoder().decode([ShopFoodItem].self, from: data)
    }

    private func ensureDailyShopIfNeeded(state: AppState) {
        let todayKey = AppState.makeDayKey(Date())

        // 日付が変わってたら更新（00:00）
        if state.shopDayKey != todayKey {
            state.shopDayKey = todayKey
            state.shopRewardResetsToday = 0
            state.shopItemsData = encodeShopItems(drawDailySix())
            save()
            return
        }

        // まだ生成されてなければ生成
        if state.shopItemsData == nil {
            state.shopItemsData = encodeShopItems(drawDailySix())
            save()
        }
    }

    private func drawDailySix() -> [ShopFoodItem] {
        // 均等確率：FoodCatalog から6件ユニーク抽選
        let picked = Array(FoodCatalog.all.shuffled().prefix(6))
        return picked.map { .init(id: $0.id, name: $0.name, kcal: $0.priceKcal, stock: 1) }
    }

    // MARK: - Buy food

    private func buyFood(itemID: String, state: AppState) {
        handleDayRolloverIfNeeded(state: state)
        ensureDailyShopIfNeeded(state: state)

        // ✅ 購入直前にも pending を反映（レース回避）
        applyPendingToWalletIfNeeded(state: state)

        guard var items = decodeShopItems(from: state) else { return }
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }

        // 在庫チェック
        guard items[idx].stock > 0 else {
            toast("売り切れです")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        let price = items[idx].kcal
        guard state.walletKcal >= price else {
            toast("kcalが足りません（必要: \(price)）")
            Haptics.rattle(duration: 0.12, style: .light)
            return
        }

        // ✅ foodId の妥当性（FoodCatalog に存在するか）
        guard FoodCatalog.byId(itemID) != nil else {
            toast("不正な商品です")
            Haptics.rattle(duration: 0.12, style: .light)
            return
        }

        // ✅ 演出開始点（ショップ表示の現在値）
        let fromDisplayed = displayedWalletKcal

        // 決済（実値）
        state.walletKcal -= price

        // ✅ 所持ご飯を +1
        _ = state.addFood(foodId: itemID, count: 1)

        // 在庫を0に
        items[idx].stock = 0
        state.shopItemsData = encodeShopItems(items)
        save()

        // ✅ ショップ内：ハプティクス無しでカウントダウン
        Task {
            await animateShopWalletCountDown(from: fromDisplayed, to: state.walletKcal)
        }

        Haptics.tap(style: .medium)
        toast("\(items[idx].name) を購入しました（-\(price)kcal）")
    }

    // ✅ ショップ内：ハプティクス無しのカウントダウン
    private func animateShopWalletCountDown(from: Int, to: Int) async {
        let start = max(0, from)
        let end = max(0, to)
        guard end != start else {
            await MainActor.run { displayedWalletKcal = end }
            return
        }

        // 減少も増加も一応対応（基本は減少想定）
        let diff = abs(end - start)

        let duration = min(0.9, max(0.22, Double(diff) * 0.006)) // 例：-100で0.6sくらい
        let fps: Double = 60
        let frames = max(1, Int(duration * fps))

        for i in 0...frames {
            let t = Double(i) / Double(frames)
            let eased = 1 - pow(1 - t, 3)

            let v = start + Int(Double(end - start) * eased)

            await MainActor.run {
                displayedWalletKcal = v
            }

            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / fps))
        }

        await MainActor.run {
            displayedWalletKcal = end
        }
    }

    // MARK: - Reward reset (dummy ad)

    private func rewardResetShopByAd(state: AppState, maxPerDay: Int) {
        handleDayRolloverIfNeeded(state: state)
        ensureDailyShopIfNeeded(state: state)

        guard state.shopRewardResetsToday < maxPerDay else {
            toast("本日のリセット上限です（\(maxPerDay)回）")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        state.shopRewardResetsToday += 1
        state.shopItemsData = encodeShopItems(drawDailySix())
        save()

        Haptics.tap(style: .light)
        toast("ショップをリセットしました（ダミー広告）")
    }

    // MARK: - Egg logic

    private func buyEgg(state: AppState) {
        handleDayRolloverIfNeeded(state: state)
        state.ensureInitialPetsIfNeeded()

        // 全コンプ後は卵購入不可
        let owned = Set(state.ownedPetIDs())
        if owned.count >= PetMaster.all.count {
            toast("全キャラコンプ済みです")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        guard !state.eggOwned else {
            toast("卵はすでに所持しています")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        guard state.friendshipCardCount >= 1 else {
            toast("なかよしカードが足りません（必要: 1枚）")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        state.friendshipCardCount -= 1
        state.eggOwned = true
        state.eggHatchAt = Date().addingTimeInterval(6 * 60 * 60) // 6h
        save()

        Haptics.tap(style: .light)
        toast("卵を購入しました（孵化まで6時間）")
    }

    private func instantHatchByAd(state: AppState) {
        handleDayRolloverIfNeeded(state: state)

        guard state.eggOwned else { return }
        guard state.eggAdUsedToday == false else {
            toast("本日の即孵化（広告）は上限です")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        // ダミー広告：即孵化可能にする
        state.eggAdUsedToday = true
        state.eggHatchAt = Date()
        save()

        Haptics.tap(style: .medium)
        toast("即孵化が可能になりました（ダミー広告）")
    }

    private func hatchEgg(state: AppState) {
        guard state.eggOwned else { return }
        guard let hatchAt = state.eggHatchAt, Date() >= hatchAt else {
            toast("まだ孵化できません")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        state.ensureInitialPetsIfNeeded()

        let owned = Set(state.ownedPetIDs())
        let notOwned = PetMaster.all.map(\.id).filter { !owned.contains($0) }

        guard let newID = notOwned.randomElement() else {
            state.eggOwned = false
            state.eggHatchAt = nil
            save()

            hatchMessage = "すべてのキャラをコンプリートしています！"
            showHatchAlert = true
            return
        }

        var nextOwned = state.ownedPetIDs()
        nextOwned.append(newID)
        state.setOwnedPetIDs(nextOwned)
        state.currentPetID = newID

        // 卵消費
        state.eggOwned = false
        state.eggHatchAt = nil
        save()

        Haptics.tap(style: .heavy)
        let name = PetMaster.all.first(where: { $0.id == newID })?.name ?? "新キャラ"
        hatchMessage = "\(name) が仲間になりました！"
        showHatchAlert = true
    }

    // MARK: - Day rollover（日次リセット：広告回数など）
    /// お世話系のリセットは AppState.ensureDailyResetIfNeeded に寄せる
    /// この画面固有の “日次” だけ追加でリセットする（卵広告、ショップ広告など）
    private func handleDayRolloverIfNeeded(state: AppState) {
        let now = Date()
        let todayKey = AppState.makeDayKey(now)
        guard state.lastDayKey != todayKey else { return }

        // ✅ 共通（日次）リセット（ご飯/お風呂広告/トイレなど）
        state.ensureDailyResetIfNeeded(now: now)

        // ✅ ショップ固有の日次リセット
        state.shopRewardResetsToday = 0

        // ✅ 卵（広告）日次リセット
        state.eggAdUsedToday = false

        // 差分同期基点
        state.lastSyncedAt = Calendar.current.startOfDay(for: now)

        save()
    }

    // MARK: - Toast

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) { showToast = false }
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
