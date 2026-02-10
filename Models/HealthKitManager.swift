//
//  HealthKitManager.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    enum AuthState: Equatable { case unknown, denied, authorized }

    @Published private(set) var authState: AuthState = .unknown

    // 今日の歩数
    @Published private(set) var todaySteps: Int = 0

    // ✅ 今日のアクティブ消費kcal（参考表示用に残す）
    @Published private(set) var todayActiveEnergyKcal: Int = 0

    // ✅ 今日の安静時消費kcal（追加）
    @Published private(set) var todayBasalEnergyKcal: Int = 0

    // ✅ 通貨として使う：今日の合計kcal（アクティブ + 安静時）
    @Published private(set) var todayTotalEnergyKcal: Int = 0

    @Published private(set) var errorMessage: String?

    private let store = HKHealthStore()

    // ✅ 同日内で「一時的に0が返る」ケースの保護（アプリ再起動で0に見える問題の緩和）
    private var lastGoodDayKey: String = ""
    private var lastGoodSteps: Int = 0
    private var lastGoodActiveKcal: Int = 0
    private var lastGoodBasalKcal: Int = 0
    private var lastGoodTotalKcal: Int = 0

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let active = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(active) }
        // ✅ 安静時消費エネルギー（Basal Energy）
        if let basal = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) { types.insert(basal) }
        return types
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authState = .denied
            errorMessage = "この端末ではHealthデータを利用できません。"
            return
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authState = .authorized
        } catch {
            authState = .denied
            errorMessage = "HealthKitの許可取得に失敗: \(error.localizedDescription)"
        }
    }

    /// ✅ 差分同期：start（前回同期）〜 now の「通貨kcal（Active + Basal）」差分を返す
    /// - Returns: (deltaKcal, newLastSyncedAt)
    func syncAndGetDeltaKcal(lastSyncedAt: Date?) async -> (deltaKcal: Int, newLastSyncedAt: Date?) {
        guard authState == .authorized else { return (0, lastSyncedAt) }

        do {
            let now = Date()
            let todayStart = Calendar.current.startOfDay(for: now)

            // ✅ lastSyncedAt が昨日以前でも「今日の0:00」に丸める（前日分が混ざる事故防止）
            let rawStart = lastSyncedAt ?? todayStart
            let start = max(rawStart, todayStart)

            // ✅ 日付が変わっていたら「良い値」保持をリセット
            let todayKey = Self.makeDayKey(now)
            if lastGoodDayKey != todayKey {
                lastGoodDayKey = todayKey
                lastGoodSteps = 0
                lastGoodActiveKcal = 0
                lastGoodBasalKcal = 0
                lastGoodTotalKcal = 0
            }

            async let steps = fetchSteps(from: todayStart, to: now)

            // 今日合計（表示用）
            async let activeToday = fetchActiveEnergyKcal(from: todayStart, to: now)
            async let basalToday = fetchBasalEnergyKcal(from: todayStart, to: now)

            // 差分（通貨加算用）
            async let activeDelta = fetchActiveEnergyKcal(from: start, to: now)
            async let basalDelta = fetchBasalEnergyKcal(from: start, to: now)

            let (s, aToday, bToday, aDelta, bDelta) = try await (steps, activeToday, basalToday, activeDelta, basalDelta)

            let totalToday = max(0, aToday) + max(0, bToday)
            let totalDelta = max(0, aDelta) + max(0, bDelta)

            // ✅ 「同日内で一時的に0」になった場合は、直近の良い値を優先
            let protectedSteps: Int = (s == 0 && lastGoodSteps > 0) ? lastGoodSteps : s

            let protectedActive: Int = (aToday == 0 && lastGoodActiveKcal > 0) ? lastGoodActiveKcal : aToday
            let protectedBasal: Int = (bToday == 0 && lastGoodBasalKcal > 0) ? lastGoodBasalKcal : bToday

            let protectedTotal: Int = (totalToday == 0 && lastGoodTotalKcal > 0) ? lastGoodTotalKcal : totalToday

            todaySteps = protectedSteps
            todayActiveEnergyKcal = protectedActive
            todayBasalEnergyKcal = protectedBasal
            todayTotalEnergyKcal = protectedTotal

            // ✅ 良い値の更新（0は採用しない）
            if protectedSteps > 0 { lastGoodSteps = protectedSteps }
            if protectedActive > 0 { lastGoodActiveKcal = protectedActive }
            if protectedBasal > 0 { lastGoodBasalKcal = protectedBasal }
            if protectedTotal > 0 { lastGoodTotalKcal = protectedTotal }

            return (max(0, totalDelta), now)
        } catch {
            errorMessage = "同期に失敗: \(error.localizedDescription)"
            return (0, lastSyncedAt)
        }
    }

    // MARK: - Fetchers

    private func predicate(from: Date, to: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
    }

    private func fetchSteps(from: Date, to: Date) async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let pred = predicate(from: from, to: to)

        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: pred,
                options: .cumulativeSum
            ) { _, result, error in
                if let error { cont.resume(throwing: error); return }
                let sum = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(sum))
            }
            store.execute(q)
        }
    }

    private func fetchActiveEnergyKcal(from: Date, to: Date) async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let pred = predicate(from: from, to: to)

        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: pred,
                options: .cumulativeSum
            ) { _, result, error in
                if let error { cont.resume(throwing: error); return }
                let sum = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                cont.resume(returning: Int(sum))
            }
            store.execute(q)
        }
    }

    // ✅ 安静時消費エネルギー（Basal Energy）
    private func fetchBasalEnergyKcal(from: Date, to: Date) async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return 0 }
        let pred = predicate(from: from, to: to)

        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: pred,
                options: .cumulativeSum
            ) { _, result, error in
                if let error { cont.resume(throwing: error); return }
                let sum = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                cont.resume(returning: Int(sum))
            }
            store.execute(q)
        }
    }

    // MARK: - DayKey

    private static func makeDayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }
}
