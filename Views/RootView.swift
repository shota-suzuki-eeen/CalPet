//
//  RootView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]
    @StateObject private var hk = HealthKitManager()

    // ✅ 起動時処理が多重実行されないようにする
    @State private var didBoot: Bool = false

    // ✅ ここで単一のAppState参照を保持して全画面で共有する
    @State private var sharedState: AppState?

    var body: some View {
        Group {
            switch hk.authState {
            case .unknown:
                AuthRequestView(
                    onAuthorize: { Task { await startAuthorizationIfNeeded() } },
                    errorMessage: hk.errorMessage
                )

            case .denied:
                DeniedView()

            case .authorized:
                if let sharedState {
                    // ✅ 重要：引数順は state → hk
                    HomeView(state: sharedState, hk: hk)
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            // ✅ 起動時にAppStateを必ず1件用意（最初に確定させる）
            let state = ensureAppState()
            sharedState = state
            state.ensureInitialPetsIfNeeded()

            // ✅ 起動処理は1回だけ
            guard !didBoot else { return }
            didBoot = true

            // ✅ 日跨ぎリセット（お世話系のフラグ・広告回数など）
            // Home/Shopのどちらから開いても整合が取れるようにRootで先に整える
            state.ensureDailyResetIfNeeded(now: Date())
            do { try modelContext.save() } catch { }

            // ✅ まだ未判定なら許可リクエスト（ここで自動で出す）
            await startAuthorizationIfNeeded()
        }
    }

    // MARK: - Authorization

    @MainActor
    private func startAuthorizationIfNeeded() async {
        guard hk.authState == .unknown else { return }
        await hk.requestAuthorization()
    }

    // MARK: - AppState（単一レコード運用）

    private func ensureAppState() -> AppState {
        if let first = appStates.first { return first }

        let created = AppState()
        modelContext.insert(created)
        do { try modelContext.save() } catch { }
        return created
    }
}

// MARK: - Shared views

private struct AuthRequestView: View {
    let onAuthorize: () -> Void
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Health連動が必要です").font(.title2).bold()
            Text("歩数と消費カロリー（Active Energy）を取得します。\n許可しない場合は利用できません。")
                .multilineTextAlignment(.center)

            Button("許可してはじめる") { onAuthorize() }
                .buttonStyle(.borderedProminent)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

private struct DeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Text("Healthの許可が必要です").font(.title2).bold()
            Text("設定アプリでHealthアクセスを許可してください。\n許可されない場合、このアプリは利用できません。")
                .multilineTextAlignment(.center)

            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
