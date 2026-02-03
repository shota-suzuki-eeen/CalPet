//
//  ContentView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var hk = HealthKitManager()

    var body: some View {
        Group {
            switch hk.authState {
            case .unknown:
                AuthRequestView(
                    errorMessage: hk.errorMessage,
                    onAuthorize: {
                        Task {
                            await hk.requestAuthorization()
                            await hk.syncToday()
                        }
                    }
                )

            case .denied:
                DeniedView()

            case .authorized:
                HomeDebugView(
                    steps: hk.todaySteps,
                    kcal: hk.todayActiveEnergyKcal,
                    errorMessage: hk.errorMessage,
                    onSync: {
                        Task { await hk.syncToday() }
                    }
                )
            }
        }
        .task {
            // 起動時：まず許可を取りに行く（仕様：Health許可ないと利用不可）
            if hk.authState == .unknown {
                await hk.requestAuthorization()
                await hk.syncToday()
            }
        }
    }
}

// MARK: - Subviews

private struct AuthRequestView: View {
    let errorMessage: String?
    let onAuthorize: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Health連動が必要です")
                .font(.title2).bold()

            Text("歩数と消費カロリー（Active Energy）を取得します。\n許可しない場合は利用できません。")
                .multilineTextAlignment(.center)

            Button("許可してはじめる") {
                onAuthorize()
            }
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
            Text("Healthの許可が必要です")
                .font(.title2).bold()

            Text("設定アプリでHealthアクセスを許可してください。\n許可されない場合、このアプリは利用できません。")
                .multilineTextAlignment(.center)

            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct HomeDebugView: View {
    let steps: Int
    let kcal: Int
    let errorMessage: String?
    let onSync: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("ホーム（デバッグ）")
                .font(.title2).bold()

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日の歩数")
                    Text("\(steps)")
                        .font(.largeTitle).bold()
                }
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日の消費kcal（Active Energy）")
                    Text("\(kcal) kcal")
                        .font(.largeTitle).bold()
                }
                Spacer()
            }

            Button("同期する") { onSync() }
                .buttonStyle(.bordered)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }
}
