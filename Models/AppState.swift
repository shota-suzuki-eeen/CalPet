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

    // ご飯フラグ（朝/昼/夜 各1回）
    var fedMorning: Bool
    var fedNoon: Bool
    var fedNight: Bool

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

        fedMorning: Bool = false,
        fedNoon: Bool = false,
        fedNight: Bool = false,

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

        self.fedMorning = fedMorning
        self.fedNoon = fedNoon
        self.fedNight = fedNight

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
    /// 日跨ぎリセット（お世話系の “今日” 依存状態を正しくクリアする）
    /// - Note: HomeViewの onAppear やアクション実行前に呼ぶ想定
    func ensureDailyResetIfNeeded(now: Date = Date()) {
        let todayKey = AppState.makeDayKey(now)
        guard lastDayKey != todayKey else { return }

        // ✅ ご飯（朝/昼/夜 各1回） → 日跨ぎで全解除
        fedMorning = false
        fedNoon = false
        fedNight = false

        // ✅ お風呂広告（最大2回/日） → 日跨ぎでリセット
        bathAdViewsToday = 0

        // ✅ トイレ：フラグは日跨ぎでクリア（持ち越し混乱防止）
        toiletFlagAt = nil
        // ✅ 最終発生時刻もクリア（翌日に最低1h制限を持ち越す必要はない）
        toiletLastRaisedAt = nil

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

// MARK: - Care (Feed / Bath / Toilet)
extension AppState {
    // ===== Feed =====

    enum FeedTimeSlot { case morning, noon, night }

    /// 現在時刻から “ご飯可能時間帯” を判定
    /// - morning: 6:00 - 10:00
    /// - noon:    12:00 - 16:00
    /// - night:   18:00 - 24:00（23:59まで）
    func currentFeedTimeSlot(now: Date = Date(), calendar: Calendar = .current) -> FeedTimeSlot? {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 6...10:   return .morning   // ✅ 10時台を含める
        case 12...16:  return .noon      // ✅ 16時台を含める
        case 18...23:  return .night     // 18-23
        default:       return nil
        }
    }

    func feedCountToday() -> Int {
        var c = 0
        if fedMorning { c += 1 }
        if fedNoon { c += 1 }
        if fedNight { c += 1 }
        return c
    }

    func didFeed(slot: FeedTimeSlot) -> Bool {
        switch slot {
        case .morning: return fedMorning
        case .noon:    return fedNoon
        case .night:   return fedNight
        }
    }

    func setFed(slot: FeedTimeSlot, value: Bool = true) {
        switch slot {
        case .morning: fedMorning = value
        case .noon:    fedNoon = value
        case .night:   fedNight = value
        }
    }

    func canFeedNow(now: Date = Date(), calendar: Calendar = .current) -> (can: Bool, slot: FeedTimeSlot?, reason: String?) {
        ensureDailyResetIfNeeded(now: now)

        guard let slot = currentFeedTimeSlot(now: now, calendar: calendar) else {
            return (false, nil, "ご飯の提供時間外です")
        }

        if didFeed(slot: slot) {
            return (false, slot, "この時間帯のご飯は既に完了しています")
        }

        if feedCountToday() >= 3 {
            return (false, slot, "本日のご飯は上限（3回）に達しています")
        }

        return (true, slot, nil)
    }

    // ===== Bath =====

    private static let bathCooldownSeconds: TimeInterval = 8 * 60 * 60
    private static let bathAdReduceSecondsPerWatch: TimeInterval = 4 * 60 * 60
    private static let bathAdLimitPerDay: Int = 2

    func canBathNow(now: Date = Date()) -> (can: Bool, remainingSeconds: TimeInterval) {
        ensureDailyResetIfNeeded(now: now)

        guard let last = bathLastAt else { return (true, 0) }

        let elapsed = now.timeIntervalSince(last)
        let remaining = AppState.bathCooldownSeconds - elapsed
        if remaining <= 0 { return (true, 0) }
        return (false, remaining)
    }

    func canUseBathAd(now: Date = Date()) -> (can: Bool, reason: String?) {
        ensureDailyResetIfNeeded(now: now)

        if bathAdViewsToday >= AppState.bathAdLimitPerDay {
            return (false, "本日の広告短縮は上限（2回）に達しています")
        }
        let bath = canBathNow(now: now)
        if bath.can {
            return (false, "クールタイムが残っていないため広告短縮は不要です")
        }
        return (true, nil)
    }

    func applyBathAdReduction(now: Date = Date()) {
        ensureDailyResetIfNeeded(now: now)

        guard bathAdViewsToday < AppState.bathAdLimitPerDay else { return }
        guard let last = bathLastAt else { return }

        bathAdViewsToday += 1
        bathLastAt = last.addingTimeInterval(-AppState.bathAdReduceSecondsPerWatch)
    }

    func markBathDone(now: Date = Date()) {
        ensureDailyResetIfNeeded(now: now)
        bathLastAt = now
    }

    // ===== Toilet =====

    private static let toiletBonusWindowSeconds: TimeInterval = 60 * 60 // 1時間
    private static let toiletMinIntervalSeconds: TimeInterval = 60 * 60 // 最低1時間間隔

    /// トイレフラグを立てられるか
    /// - フラグが立っている間は次のフラグは立たない
    /// - 最低でも1時間は間隔（= 前回フラグ発生から1h未満はNG）
    func canRaiseToiletFlag(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)

        if toiletFlagAt != nil { return false }

        if let last = toiletLastRaisedAt {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < AppState.toiletMinIntervalSeconds {
                return false
            }
        }
        return true
    }

    /// トイレフラグを立てる（ランダムタイミングで呼ぶ想定）
    @discardableResult
    func raiseToiletFlag(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)

        guard canRaiseToiletFlag(now: now) else { return false }

        toiletFlagAt = now
        toiletLastRaisedAt = now
        return true
    }

    /// トイレ対応（フラグが立っている時のみ）
    /// - Returns: 1時間以内だったか（= 2倍の扱い）
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
