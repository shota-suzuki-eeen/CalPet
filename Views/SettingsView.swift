//
//  SettingsView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/05.
//

import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]

    @State private var goalText: String = ""
    @State private var errorMessage: String?

    // ✅ Home側と揃える：初回目標設定済みフラグ
    @AppStorage("didSetDailyGoalOnce") private var didSetDailyGoalOnce: Bool = false

    // ✅ 編集モード制御
    @State private var isEditingGoal: Bool = false

    // トースト（任意）
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    private let bgColor = Color(red: 0.35, green: 0.86, blue: 0.88)

    var body: some View {
        let state = ensureAppState()

        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // タイトル
                    Text("設定")
                        .font(.title2).bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    // 目標設定カード
                    VStack(alignment: .leading, spacing: 10) {
                        Text("目標消費カロリー（kcal）")
                            .font(.headline)

                        Text("ここで設定した数値はHome画面の目標値と連動します。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        // ✅ 表示モード（編集前）
                        if !isEditingGoal {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("現在の目標")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    Text(state.dailyGoalKcal > 0 ? "\(state.dailyGoalKcal) kcal" : "未設定")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.primary)
                                }

                                Spacer()

                                Button("編集") {
                                    errorMessage = nil
                                    // 編集開始時に現在値を反映
                                    goalText = state.dailyGoalKcal > 0 ? String(state.dailyGoalKcal) : ""
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isEditingGoal = true
                                    }
                                    Haptics.rattle(duration: 0.08, style: .light)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            // ✅ 編集モード（編集ボタン押下後）
                            HStack(spacing: 10) {
                                TextField("例：300", text: $goalText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)

                                Button("保存") {
                                    saveGoal(state: state)
                                }
                                .buttonStyle(.borderedProminent)

                                Button("キャンセル") {
                                    errorMessage = nil
                                    // 入力を現在値に戻して終了
                                    goalText = state.dailyGoalKcal > 0 ? String(state.dailyGoalKcal) : ""
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isEditingGoal = false
                                    }
                                    Haptics.rattle(duration: 0.08, style: .light)
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(14)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            // Toast（任意）
            VStack {
                Spacer()
                if showToast, let toastMessage {
                    Text(toastMessage)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 8)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 初回表示時：編集状態はOFF、表示用テキストは現在値に合わせる
            isEditingGoal = false
            goalText = state.dailyGoalKcal > 0 ? String(state.dailyGoalKcal) : ""

            // ✅ すでにgoalが入っているなら「初回設定済み」とみなす（端末移行/デバッグでも破綻しにくく）
            if state.dailyGoalKcal > 0, didSetDailyGoalOnce == false {
                didSetDailyGoalOnce = true
            }
        }
    }

    // MARK: - Actions

    private func saveGoal(state: AppState) {
        errorMessage = nil

        guard let v = Int(goalText), v > 0 else {
            errorMessage = "1以上の数値を入力してください。"
            Haptics.rattle(duration: 0.12, style: .light)
            return
        }

        state.dailyGoalKcal = v

        do {
            try modelContext.save()

            // ✅ 保存できたら「初回設定済み」にする（Homeでシートが二度と出ない）
            didSetDailyGoalOnce = true

            Haptics.rattle(duration: 0.18, style: .light)
            toast("目標を保存しました")
            withAnimation(.easeInOut(duration: 0.15)) {
                isEditingGoal = false
            }
        } catch {
            errorMessage = "保存に失敗しました。"
        }
    }

    // MARK: - AppState

    private func ensureAppState() -> AppState {
        if let first = appStates.first { return first }
        let created = AppState(
            walletKcal: 0,
            pendingKcal: 0,
            lastSyncedAt: nil,
            dailyGoalKcal: 0,
            lastDayKey: AppState.makeDayKey(Date())
        )
        modelContext.insert(created)
        do { try modelContext.save() } catch { }
        return created
    }

    // MARK: - Toast

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) { showToast = false }
        }
    }
}
