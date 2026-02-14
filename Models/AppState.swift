//
//  AppState.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import Foundation
import SwiftData

@Model
final class AppState {
    // ✅ なかよし度メーター上限（0..(max-1)）
    static let friendshipMaxMeter: Int = 100

    // MARK: - Currency (kcal)
    // ✅ 通貨定義（仕様確定）
    // - 通貨kcal = Active Energy + Basal Energy（安静時消費エネルギー）
    // - walletKcal : 実際に「所持」していて購入に使える通貨
    // - pendingKcal: 同期差分などで一時的に貯める用途（必要なら使用）
    var walletKcal: Int
    var pendingKcal: Int

    // MARK: - Health Sync
    var lastSyncedAt: Date?

    // MARK: - Goal
    var dailyGoalKcal: Int

    // 日跨ぎ判定用（yyyyMMdd）
    var lastDayKey: String

    // MARK: - Today Cache (Offline / Protect Zero)
    // ✅ 今日の歩数／消費kcal（キャッシュ：オフライン用）
    // - cachedTodayKcal は「今日の通貨kcal（Active+Basalの合計）」を入れる
    var cachedTodaySteps: Int
    var cachedTodayKcal: Int

    // ✅ なかよし度（0..99）＆カード
    var friendshipPoint: Int
    var friendshipCardCount: Int

    // MARK: - ✅ Satisfaction (Feed Spec: NEW)
    // ✅ 満足度（0..3）
    // - 3 が最大
    // - 2時間で 1 減少（= 6h で 3 → 0）
    // - 最大(3)のときはご飯をあげられない
    // - 「満足度0の状態で3回あげられる」＝ 0→1→2→3
    var satisfactionLevel: Int

    // ✅ 満足度の“減少計算”の基準時刻
    // - ここからの経過時間で減少を計算する
    var satisfactionLastUpdatedAt: Date?

    // ✅ お風呂
    var bathLastAt: Date?           // 最後にお風呂した時刻
    var bathAdViewsToday: Int       // 今日の広告短縮回数（最大2）

    // ✅ トイレ
    var toiletFlagAt: Date?         // フラグ発生時刻（nilならフラグなし）
    var toiletLastRaisedAt: Date?   // ✅ 最後にフラグを立てた時刻（最低1時間間隔用）

    // ✅ 卵（ショップ）
    var eggOwned: Bool              // 卵所持（同時に1個まで）
    var eggHatchAt: Date?           // 孵化可能時刻（購入+6h）
    var eggAdUsedToday: Bool        // 今日の即孵化広告（最大1回）

    // ✅ デイリーショップ（MVP）
    var shopDayKey: String          // ショップ更新日（yyyyMMdd）
    var shopItemsData: Data?        // 6品ラインナップ（JSON）
    var shopRewardResetsToday: Int  // リワードでのリセット回数（例：最大2/日）

    // ✅ キャラ（MVP）
    var currentPetID: String        // 育て中キャラID
    var ownedPetIDsData: Data?      // 所持キャラID配列（JSON）

    // ✅ 通知設定（MVP：トグル保存のみ）
    var notifyFeed: Bool
    var notifyBath: Bool
    var notifyToilet: Bool

    // ✅ ご飯インベントリ（今回追加）
    // FoodCatalog.FoodItem.id をキーに所持数を保存（JSON: [String:Int]）
    var ownedFoodCountsData: Data?

    init(
        walletKcal: Int = 0,
        pendingKcal: Int = 0,
        lastSyncedAt: Date? = nil,
        dailyGoalKcal: Int = 0,
        lastDayKey: String = AppState.makeDayKey(Date()),

        cachedTodaySteps: Int = 0,
        cachedTodayKcal: Int = 0,

        friendshipPoint: Int = 0,
        friendshipCardCount: Int = 0,

        // ✅ 満足度（初期値は最大）
        satisfactionLevel: Int = 3,
        satisfactionLastUpdatedAt: Date? = nil,

        bathLastAt: Date? = nil,
        bathAdViewsToday: Int = 0,

        toiletFlagAt: Date? = nil,
        toiletLastRaisedAt: Date? = nil,

        eggOwned: Bool = false,
        eggHatchAt: Date? = nil,
        eggAdUsedToday: Bool = false,

        shopDayKey: String = AppState.makeDayKey(Date()),
        shopItemsData: Data? = nil,
        shopRewardResetsToday: Int = 0,

        currentPetID: String = "pet_000",
        ownedPetIDsData: Data? = nil,

        notifyFeed: Bool = true,
        notifyBath: Bool = true,
        notifyToilet: Bool = true,

        ownedFoodCountsData: Data? = nil
    ) {
        self.walletKcal = walletKcal
        self.pendingKcal = pendingKcal

        self.lastSyncedAt = lastSyncedAt

        self.dailyGoalKcal = dailyGoalKcal
        self.lastDayKey = lastDayKey

        self.cachedTodaySteps = cachedTodaySteps
        self.cachedTodayKcal = cachedTodayKcal

        self.friendshipPoint = friendshipPoint
        self.friendshipCardCount = friendshipCardCount

        self.satisfactionLevel = satisfactionLevel
        self.satisfactionLastUpdatedAt = satisfactionLastUpdatedAt

        self.bathLastAt = bathLastAt
        self.bathAdViewsToday = bathAdViewsToday

        self.toiletFlagAt = toiletFlagAt
        self.toiletLastRaisedAt = toiletLastRaisedAt

        self.eggOwned = eggOwned
        self.eggHatchAt = eggHatchAt
        self.eggAdUsedToday = eggAdUsedToday

        self.shopDayKey = shopDayKey
        self.shopItemsData = shopItemsData
        self.shopRewardResetsToday = shopRewardResetsToday

        self.currentPetID = currentPetID
        self.ownedPetIDsData = ownedPetIDsData

        self.notifyFeed = notifyFeed
        self.notifyBath = notifyBath
        self.notifyToilet = notifyToilet

        self.ownedFoodCountsData = ownedFoodCountsData
    }

    static func makeDayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }
}

// MARK: - Currency helpers（今回追加：安全に pending → wallet へ移す）
extension AppState {
    /// pendingKcal を walletKcal に移して、移動した量を返す（0以上）
    /// - HomeView 側で「購入可能にするため即反映」する時に便利
    @discardableResult
    func drainPendingKcalToWallet() -> Int {
        let delta = max(0, pendingKcal)
        guard delta > 0 else { return 0 }
        walletKcal += delta
        pendingKcal = 0
        return delta
    }
}

// MARK: - Food Inventory（今回追加）
extension AppState {
    private func ownedFoodCounts() -> [String: Int] {
        guard let data = ownedFoodCountsData,
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func setOwnedFoodCounts(_ dict: [String: Int]) {
        ownedFoodCountsData = try? JSONEncoder().encode(dict)
    }

    /// 所持数を取得
    func foodCount(foodId: String) -> Int {
        let dict = ownedFoodCounts()
        return max(0, dict[foodId] ?? 0)
    }

    /// 所持している foodId の中から、先頭（ids順）を返す
    func firstOwnedFoodId(from ids: [String]) -> String? {
        for id in ids {
            if foodCount(foodId: id) > 0 { return id }
        }
        return nil
    }

    /// 所持数を加算（ショップ購入で使う想定）
    @discardableResult
    func addFood(foodId: String, count: Int = 1) -> Bool {
        let add = max(0, count)
        guard add > 0 else { return false }

        var dict = ownedFoodCounts()
        let current = max(0, dict[foodId] ?? 0)
        dict[foodId] = current + add
        setOwnedFoodCounts(dict)
        return true
    }

    /// 所持数を消費（Homeで“あげる”で使う想定）
    @discardableResult
    func consumeFood(foodId: String, count: Int = 1) -> Bool {
        let use = max(0, count)
        guard use > 0 else { return false }

        var dict = ownedFoodCounts()
        let current = max(0, dict[foodId] ?? 0)
        guard current >= use else { return false }

        let next = current - use
        if next <= 0 {
            dict.removeValue(forKey: foodId)
        } else {
            dict[foodId] = next
        }
        setOwnedFoodCounts(dict)
        return true
    }
}

// MARK: - Day Reset (Care Spec)
extension AppState {
    /// ✅ 日跨ぎリセット（お世話系の “今日” 依存状態を正しくクリアする）
    /// - Note: これは「明示的に」呼ぶ（例：HomeViewの onAppear / フォア復帰 / アクション実行前）
    /// - ⚠️ 重要：UIの描画中に頻繁に呼ばれる “判定関数” の中では呼ばない（フリーズの温床になる）
    func ensureDailyResetIfNeeded(now: Date = Date()) {
        let todayKey = AppState.makeDayKey(now)
        guard lastDayKey != todayKey else { return }

        // ✅ お風呂広告（最大2回/日） → 日跨ぎでリセット
        bathAdViewsToday = 0

        // ✅ トイレ：フラグは日跨ぎでクリア（持ち越し混乱防止）
        toiletFlagAt = nil
        // ✅ 最終発生時刻もクリア（翌日に最低1h制限を持ち越す必要はない）
        toiletLastRaisedAt = nil

        // ✅ 満足度：日跨ぎで基準時刻を揃える（減衰計算の不整合を防ぐ）
        // - 値そのものは維持（ゲーム仕様次第でここを 3 に戻す等も可能）
        if satisfactionLastUpdatedAt == nil {
            satisfactionLastUpdatedAt = now
        }

        // 既存の lastDayKey 更新
        lastDayKey = todayKey
    }
}

// MARK: - Today Cache helpers（再起動で0上書きされるのを防ぐ用途）
extension AppState {
    struct CacheUpdateResult: Equatable {
        let stepsToUse: Int
        let kcalToUse: Int
        let didUpdateStepsCache: Bool
        let didUpdateKcalCache: Bool
    }

    /// ✅ fetchedKcal は「通貨kcal（Active+Basalの合計）」を渡すこと
    func updateTodayCacheProtectingZero(
        fetchedSteps: Int,
        fetchedKcal: Int,
        todayKey: String
    ) -> CacheUpdateResult {
        // ここは “todayKey” を外から渡しているので副作用は最小限に保つ
        if lastDayKey != todayKey {
            cachedTodaySteps = 0
            cachedTodayKcal = 0
        }

        let prevSteps = cachedTodaySteps
        let prevKcal = cachedTodayKcal

        let protectSteps = (fetchedSteps == 0 && prevSteps > 0)
        let protectKcal  = (fetchedKcal == 0 && prevKcal > 0)

        let stepsToUse = protectSteps ? prevSteps : fetchedSteps
        let kcalToUse  = protectKcal  ? prevKcal  : fetchedKcal

        var didUpdateStepsCache = false
        var didUpdateKcalCache = false

        if !protectSteps {
            cachedTodaySteps = stepsToUse
            didUpdateStepsCache = true
        }
        if !protectKcal {
            cachedTodayKcal = kcalToUse
            didUpdateKcalCache = true
        }

        return .init(
            stepsToUse: stepsToUse,
            kcalToUse: kcalToUse,
            didUpdateStepsCache: didUpdateStepsCache,
            didUpdateKcalCache: didUpdateKcalCache
        )
    }
}

// MARK: - Friendship
extension AppState {
    struct FriendshipGainResult: Equatable {
        let beforePoint: Int
        let afterPoint: Int
        let gainedCards: Int
        let didWrap: Bool
        let didReachMax: Bool
    }

    @discardableResult
    func addFriendship(points: Int, maxMeter: Int = AppState.friendshipMaxMeter) -> FriendshipGainResult {
        let before = friendshipPoint
        let gain = max(0, points)
        let total = friendshipPoint + gain
        let didReachMax = (before < maxMeter) && (total >= maxMeter)

        if total >= maxMeter {
            let cards = total / maxMeter
            friendshipCardCount += cards
            friendshipPoint = total % maxMeter

            return .init(
                beforePoint: before,
                afterPoint: friendshipPoint,
                gainedCards: cards,
                didWrap: true,
                didReachMax: didReachMax
            )
        } else {
            friendshipPoint = total
            return .init(
                beforePoint: before,
                afterPoint: friendshipPoint,
                gainedCards: 0,
                didWrap: false,
                didReachMax: didReachMax
            )
        }
    }
}

// MARK: - ✅ Satisfaction (Feed / Decay: NEW)
// ⚠️ 重要：UI描画中に頻繁に呼ばれる関数は “副作用なし” にする（ここがフリーズ対策の肝）
extension AppState {
    // 2時間で1減少
    private static let satisfactionDecayUnitSeconds: TimeInterval = 2 * 60 * 60
    private static let satisfactionMax: Int = 3

    /// 満足度を 0...3 にクランプ
    private func clampSatisfaction(_ v: Int) -> Int {
        min(AppState.satisfactionMax, max(0, v))
    }

    /// ✅（副作用なし）現在時刻における “表示上の満足度” を計算して返す
    /// - satisfactionLevel / satisfactionLastUpdatedAt を「書き換えない」
    private func computedSatisfaction(now: Date = Date()) -> (level: Int, effectiveLastUpdatedAt: Date?) {
        let current = clampSatisfaction(satisfactionLevel)

        guard let last = satisfactionLastUpdatedAt else {
            // 基準がない場合は「現状値のまま」表示（初回設定は別のタイミングで行う）
            return (current, nil)
        }

        let elapsed = now.timeIntervalSince(last)
        if elapsed <= 0 {
            return (current, last)
        }

        let steps = Int(floor(elapsed / AppState.satisfactionDecayUnitSeconds))
        if steps <= 0 {
            return (current, last)
        }

        let after = clampSatisfaction(current - steps)

        // “減った分だけ”進んだ基準時刻（ただし保存はしない）
        let advanced = TimeInterval(steps) * AppState.satisfactionDecayUnitSeconds
        let effLast = last.addingTimeInterval(advanced)

        return (after, effLast)
    }

    /// ✅（副作用なし）UI表示用：現在の満足度
    func currentSatisfaction(now: Date = Date()) -> Int {
        computedSatisfaction(now: now).level
    }

    /// ✅（副作用なし）ご飯をあげられるか（満足度が最大でない時だけOK）
    func canFeedNow(now: Date = Date()) -> (can: Bool, reason: String?) {
        let level = computedSatisfaction(now: now).level
        if level >= AppState.satisfactionMax {
            return (false, "満足度が最大のためご飯をあげられません")
        }
        return (true, nil)
    }

    /// ✅（副作用あり：アクション用）時間経過の減少を “保存” する
    /// - これは HomeView のボタン処理（ご飯をあげる等）の直前に呼ばれる想定
    @discardableResult
    func applySatisfactionDecayIfNeeded(now: Date = Date()) -> Int {
        // アクション実行前にだけ daily reset を許可（描画中ループの原因にしない）
        ensureDailyResetIfNeeded(now: now)

        // 初回は基準時刻を設定して終了（減少は次回以降）
        guard satisfactionLastUpdatedAt != nil else {
            satisfactionLastUpdatedAt = now
            satisfactionLevel = clampSatisfaction(satisfactionLevel)
            return satisfactionLevel
        }

        let computed = computedSatisfaction(now: now)
        // 計算結果を保存
        satisfactionLevel = clampSatisfaction(computed.level)
        if let eff = computed.effectiveLastUpdatedAt {
            satisfactionLastUpdatedAt = eff
        }
        return satisfactionLevel
    }

    /// ✅ ご飯を1回あげる（満足度 +1、最大3）
    /// - ここは “アクション” なので副作用ありでOK
    @discardableResult
    func feedOnce(now: Date = Date()) -> (didFeed: Bool, before: Int, after: Int, reason: String?) {
        // アクション前に減衰を確定
        _ = applySatisfactionDecayIfNeeded(now: now)

        let before = satisfactionLevel
        guard before < AppState.satisfactionMax else {
            return (false, before, before, "満足度が最大のためご飯をあげられません")
        }

        let after = clampSatisfaction(before + 1)
        satisfactionLevel = after

        // ✅ “あげた瞬間” を基準に減少開始
        satisfactionLastUpdatedAt = now

        return (true, before, after, nil)
    }
}

// MARK: - Care (Bath / Toilet)
// ⚠️ 判定系（can〜）は副作用なし、実行系（mark/apply/raise/resolve）は副作用ありOK
extension AppState {
    // ===== Bath =====

    private static let bathCooldownSeconds: TimeInterval = 8 * 60 * 60
    private static let bathAdReduceSecondsPerWatch: TimeInterval = 4 * 60 * 60
    private static let bathAdLimitPerDay: Int = 2

    /// ✅（副作用なし）お風呂できるか
    func canBathNow(now: Date = Date()) -> (can: Bool, remainingSeconds: TimeInterval) {
        guard let last = bathLastAt else { return (true, 0) }

        let elapsed = now.timeIntervalSince(last)
        let remaining = AppState.bathCooldownSeconds - elapsed
        if remaining <= 0 { return (true, 0) }
        return (false, remaining)
    }

    /// ✅（副作用なし）広告短縮できるか
    func canUseBathAd(now: Date = Date()) -> (can: Bool, reason: String?) {
        if bathAdViewsToday >= AppState.bathAdLimitPerDay {
            return (false, "本日の広告短縮は上限（2回）に達しています")
        }
        let bath = canBathNow(now: now)
        if bath.can {
            return (false, "クールタイムが残っていないため広告短縮は不要です")
        }
        return (true, nil)
    }

    /// ✅（副作用あり：アクション）広告短縮を適用
    func applyBathAdReduction(now: Date = Date()) {
        ensureDailyResetIfNeeded(now: now)

        guard bathAdViewsToday < AppState.bathAdLimitPerDay else { return }
        guard let last = bathLastAt else { return }

        bathAdViewsToday += 1
        bathLastAt = last.addingTimeInterval(-AppState.bathAdReduceSecondsPerWatch)
    }

    /// ✅（副作用あり：アクション）お風呂実行
    func markBathDone(now: Date = Date()) {
        ensureDailyResetIfNeeded(now: now)
        bathLastAt = now
    }

    // ===== Toilet =====

    private static let toiletBonusWindowSeconds: TimeInterval = 60 * 60 // 1時間
    private static let toiletMinIntervalSeconds: TimeInterval = 60 * 60 // 最低1時間間隔

    /// ✅（副作用なし）トイレフラグを立てられるか
    func canRaiseToiletFlag(now: Date = Date()) -> Bool {
        if toiletFlagAt != nil { return false }

        if let last = toiletLastRaisedAt {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < AppState.toiletMinIntervalSeconds {
                return false
            }
        }
        return true
    }

    /// ✅（副作用あり：アクション）トイレフラグを立てる
    @discardableResult
    func raiseToiletFlag(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)

        guard canRaiseToiletFlag(now: now) else { return false }

        toiletFlagAt = now
        toiletLastRaisedAt = now
        return true
    }

    /// ✅（副作用あり：アクション）トイレ対応
    func resolveToilet(now: Date = Date()) -> (didResolve: Bool, isWithin1h: Bool) {
        ensureDailyResetIfNeeded(now: now)

        guard let flagAt = toiletFlagAt else {
            return (false, false)
        }

        let elapsed = now.timeIntervalSince(flagAt)
        let within = elapsed <= AppState.toiletBonusWindowSeconds

        toiletFlagAt = nil
        return (true, within)
    }
}

// MARK: - Pets (owned list helpers)
extension AppState {
    func ownedPetIDs() -> [String] {
        guard let data = ownedPetIDsData,
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    func setOwnedPetIDs(_ ids: [String]) {
        ownedPetIDsData = try? JSONEncoder().encode(ids)
    }

    func ensureInitialPetsIfNeeded() {
        var ids = ownedPetIDs()
        if ids.isEmpty {
            ids = ["pet_000"]
            setOwnedPetIDs(ids)
            currentPetID = "pet_000"
        }
    }
}
