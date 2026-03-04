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
    var walletKcal: Int
    var pendingKcal: Int

    // MARK: - Health Sync
    var lastSyncedAt: Date?

    // MARK: - Goal
    var dailyGoalKcal: Int

    // 日跨ぎ判定用（yyyyMMdd）
    var lastDayKey: String

    // MARK: - Today Cache (Offline / Protect Zero)
    var cachedTodaySteps: Int
    var cachedTodayKcal: Int

    // ✅ なかよし度（0..99）＆カード
    var friendshipPoint: Int
    var friendshipCardCount: Int

    // MARK: - ✅ Satisfaction (Feed Spec: NEW)
    // ✅ 重要：初期値が 3 だと満足度MAXで永遠にご飯できないので 0 にする
    var satisfactionLevel: Int
    var satisfactionLastUpdatedAt: Date?

    // ✅ お風呂
    var bathLastAt: Date?
    var bathAdViewsToday: Int

    // ✅ トイレ
    var toiletFlagAt: Date?
    var toiletLastRaisedAt: Date?

    // ✅ 卵（ショップ）
    var eggOwned: Bool
    var eggHatchAt: Date?
    var eggAdUsedToday: Bool

    // ✅ デイリーショップ（MVP）
    var shopDayKey: String
    var shopItemsData: Data?
    var shopRewardResetsToday: Int

    // ✅ キャラ（MVP）
    var currentPetID: String
    var ownedPetIDsData: Data?

    // ✅ 通知設定（MVP：トグル保存のみ）
    var notifyFeed: Bool
    var notifyBath: Bool
    var notifyToilet: Bool

    // ✅ ご飯インベントリ
    var ownedFoodCountsData: Data?

    // MARK: - ✅ Super Favorite Reveal (NEW)
    // ⚠️ SwiftDataのマイグレーション安定のため「宣言側」にデフォルトを置く
    // petID -> Bool（大好物が判明しているか）
    var superFavoriteRevealedData: Data? = nil

    // MARK: - ✅ Moja (NEW)
    // ⚠️ 重要：SwiftDataのマイグレーション安定のため「宣言側」にデフォルトを置く
    // （init の default だけだと既存ストアからの移行で値が入らず、AppStateが読めない原因になりやすい）
    var mojaCount: Int = 0
    var mojaFusionIsRunning: Bool = false
    var mojaFusionEndAt: Date? = nil

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

        // ✅ 修正：初期満足度は 0（MAX=3）
        satisfactionLevel: Int = 0,
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

        ownedFoodCountsData: Data? = nil,

        // ✅ Super Favorite Reveal (NEW)
        superFavoriteRevealedData: Data? = nil,

        // ✅ Moja (NEW) ※呼び出し側が指定したい場合のため引数は残す
        mojaCount: Int = 0,
        mojaFusionIsRunning: Bool = false,
        mojaFusionEndAt: Date? = nil
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

        // ✅ Super Favorite Reveal (NEW)
        self.superFavoriteRevealedData = superFavoriteRevealedData

        // ✅ Moja (NEW)
        self.mojaCount = mojaCount
        self.mojaFusionIsRunning = mojaFusionIsRunning
        self.mojaFusionEndAt = mojaFusionEndAt
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

    func foodCount(foodId: String) -> Int {
        let dict = ownedFoodCounts()
        return max(0, dict[foodId] ?? 0)
    }

    func firstOwnedFoodId(from ids: [String]) -> String? {
        for id in ids {
            if foodCount(foodId: id) > 0 { return id }
        }
        return nil
    }

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

// MARK: - ✅ Super Favorite Reveal helpers (NEW)
extension AppState {
    private func superFavoriteRevealedMap() -> [String: Bool] {
        guard let data = superFavoriteRevealedData,
              let dict = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func setSuperFavoriteRevealedMap(_ dict: [String: Bool]) {
        superFavoriteRevealedData = try? JSONEncoder().encode(dict)
    }

    /// ✅ 大好物が判明しているか
    func isSuperFavoriteRevealed(petID: String) -> Bool {
        let dict = superFavoriteRevealedMap()
        return dict[petID] ?? false
    }

    /// ✅ 大好物を判明済みにする（すでにtrueなら何もしない）
    @discardableResult
    func revealSuperFavorite(petID: String) -> Bool {
        // 図鑑対象外のIDを誤って入れない保険（必要なければ外してOK）
        if !isValidZukanPetID(petID) { return false }

        var dict = superFavoriteRevealedMap()
        if dict[petID] == true { return false }

        dict[petID] = true
        setSuperFavoriteRevealedMap(dict)
        return true
    }
}

// MARK: - Day Reset (Care Spec)
extension AppState {
    func ensureDailyResetIfNeeded(now: Date = Date()) {
        let todayKey = AppState.makeDayKey(now)
        guard lastDayKey != todayKey else { return }

        bathAdViewsToday = 0
        toiletFlagAt = nil
        toiletLastRaisedAt = nil

        if satisfactionLastUpdatedAt == nil {
            satisfactionLastUpdatedAt = now
        }

        // ✅ Moja：リアル時間進行のため日跨ぎでリセットしない
        // ✅ 大好物判明：永続のため日跨ぎでリセットしない

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

// MARK: - ✅ Satisfaction (Feed / Decay: NEW)
extension AppState {
    private static let satisfactionDecayUnitSeconds: TimeInterval = 2 * 60 * 60
    private static let satisfactionMax: Int = 3

    private func clampSatisfaction(_ v: Int) -> Int {
        min(AppState.satisfactionMax, max(0, v))
    }

    private func computedSatisfaction(now: Date = Date()) -> (level: Int, effectiveLastUpdatedAt: Date?) {
        let current = clampSatisfaction(satisfactionLevel)

        guard let last = satisfactionLastUpdatedAt else {
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
        let advanced = TimeInterval(steps) * AppState.satisfactionDecayUnitSeconds
        let effLast = last.addingTimeInterval(advanced)

        return (after, effLast)
    }

    func currentSatisfaction(now: Date = Date()) -> Int {
        computedSatisfaction(now: now).level
    }

    func canFeedNow(now: Date = Date()) -> (can: Bool, reason: String?) {
        let level = computedSatisfaction(now: now).level
        if level >= AppState.satisfactionMax {
            return (false, "満足度が最大のためご飯をあげられません")
        }
        return (true, nil)
    }

    @discardableResult
    func applySatisfactionDecayIfNeeded(now: Date = Date()) -> Int {
        ensureDailyResetIfNeeded(now: now)

        guard satisfactionLastUpdatedAt != nil else {
            satisfactionLastUpdatedAt = now
            satisfactionLevel = clampSatisfaction(satisfactionLevel)
            return satisfactionLevel
        }

        let computed = computedSatisfaction(now: now)
        satisfactionLevel = clampSatisfaction(computed.level)
        if let eff = computed.effectiveLastUpdatedAt {
            satisfactionLastUpdatedAt = eff
        }
        return satisfactionLevel
    }

    @discardableResult
    func feedOnce(now: Date = Date()) -> (didFeed: Bool, before: Int, after: Int, reason: String?) {
        _ = applySatisfactionDecayIfNeeded(now: now)

        let before = satisfactionLevel
        guard before < AppState.satisfactionMax else {
            return (false, before, before, "満足度が最大のためご飯をあげられません")
        }

        let after = clampSatisfaction(before + 1)
        satisfactionLevel = after
        satisfactionLastUpdatedAt = now

        return (true, before, after, nil)
    }
}

// MARK: - Care (Bath / Toilet)
extension AppState {
    private static let bathCooldownSeconds: TimeInterval = 8 * 60 * 60
    private static let bathAdReduceSecondsPerWatch: TimeInterval = 4 * 60 * 60
    private static let bathAdLimitPerDay: Int = 2

    func canBathNow(now: Date = Date()) -> (can: Bool, remainingSeconds: TimeInterval) {
        guard let last = bathLastAt else { return (true, 0) }

        let elapsed = now.timeIntervalSince(last)
        let remaining = AppState.bathCooldownSeconds - elapsed
        if remaining <= 0 { return (true, 0) }
        return (false, remaining)
    }

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

    private static let toiletBonusWindowSeconds: TimeInterval = 60 * 60
    private static let toiletMinIntervalSeconds: TimeInterval = 60 * 60

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

    @discardableResult
    func raiseToiletFlag(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)

        guard canRaiseToiletFlag(now: now) else { return false }

        toiletFlagAt = now
        toiletLastRaisedAt = now
        return true
    }

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
    /// ✅ 図鑑の初期実装予定：12体（pet_000 ... pet_011）
    /// View / ViewModel で同じ配列を持つとズレの原因になるため AppState 側に集約
    static let initialZukanPetIDs: [String] = (0..<12).map { String(format: "pet_%03d", $0) }

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

    /// ✅ 追加：未所持の中から1体を完全ランダムで獲得する
    /// - すでに全て所持している場合は nil
    /// - 獲得したIDは ownedPetIDs に追加（重複しない）
    /// - currentPetID は変更しない（既存仕様を壊さない）
    @discardableResult
    func acquireRandomPetIfPossible() -> String? {
        var owned = ownedPetIDs()
        let ownedSet = Set(owned)

        let candidates = AppState.initialZukanPetIDs.filter { !ownedSet.contains($0) }
        guard let picked = candidates.randomElement() else { return nil }

        owned.append(picked)
        setOwnedPetIDs(owned)
        return picked
    }

    /// ✅ 追加：図鑑IDとして有効か（保険）
    func isValidZukanPetID(_ id: String) -> Bool {
        AppState.initialZukanPetIDs.contains(id)
    }
}

// MARK: - ✅ Moja helpers (NEW)
extension AppState {
    @discardableResult
    func addMoja(_ count: Int = 1) -> Bool {
        let add = max(0, count)
        guard add > 0 else { return false }
        mojaCount += add
        return true
    }

    @discardableResult
    func consumeMoja(_ count: Int = 1) -> Bool {
        let use = max(0, count)
        guard use > 0 else { return false }
        guard mojaCount >= use else { return false }
        mojaCount -= use
        return true
    }

    @discardableResult
    func startMojaFusion(cost: Int = 1, now: Date = Date()) -> Bool {
        guard mojaFusionIsRunning == false else { return false }
        guard consumeMoja(cost) else { return false }

        mojaFusionIsRunning = true
        mojaFusionEndAt = now.addingTimeInterval(6 * 60 * 60)
        return true
    }

    func mojaFusionRemainingSeconds(now: Date = Date()) -> TimeInterval? {
        guard mojaFusionIsRunning, let end = mojaFusionEndAt else { return nil }
        return max(0, end.timeIntervalSince(now))
    }

    @discardableResult
    func finalizeMojaFusionIfNeeded(now: Date = Date()) -> Bool {
        guard mojaFusionIsRunning, let end = mojaFusionEndAt else { return false }
        guard now >= end else { return false }

        mojaFusionIsRunning = false
        mojaFusionEndAt = nil
        return true
    }

    func reduceMojaFusion(seconds: TimeInterval) {
        guard mojaFusionIsRunning, let end = mojaFusionEndAt else { return }
        let reduce = max(0, seconds)
        guard reduce > 0 else { return }
        mojaFusionEndAt = end.addingTimeInterval(-reduce)
    }
}
