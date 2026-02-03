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
    enum AuthState: Equatable {
        case unknown
        case denied
        case authorized
    }

    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var todayActiveEnergyKcal: Int = 0
    @Published private(set) var errorMessage: String?

    private let store = HKHealthStore()

    // 読み取り対象（MVP）
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
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

            // ✅ MVPでは「ここまで来たら authorized 扱い」でOK
            // 実際に取れない/拒否されてる場合は syncToday() 側で error に出る
            authState = .authorized
        } catch {
            authState = .denied
            errorMessage = "HealthKitの許可取得に失敗: \(error.localizedDescription)"
        }
    }

    /// 今日の歩数＆Active Energy（kcal）を取得
    func syncToday() async {
        guard authState == .authorized else { return }

        do {
            async let steps = fetchTodaySteps()
            async let energy = fetchTodayActiveEnergyKcal()
            let (s, e) = try await (steps, energy)

            todaySteps = s
            todayActiveEnergyKcal = e
        } catch {
            errorMessage = "同期に失敗: \(error.localizedDescription)"
        }
    }

    // MARK: - Private fetchers

    private func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func predicateForToday() -> NSPredicate {
        let start = startOfToday()
        let end = Date()
        return HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    }

    private func fetchTodaySteps() async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let predicate = predicateForToday()

        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                let sum = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(sum))
            }
            store.execute(query)
        }
    }

    private func fetchTodayActiveEnergyKcal() async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let predicate = predicateForToday()

        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                let sum = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                cont.resume(returning: Int(sum))
            }
            store.execute(query)
        }
    }
}
