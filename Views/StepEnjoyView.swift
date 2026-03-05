import SwiftUI

struct StepEnjoyView: View {
    @Environment(\.dismiss) private var dismiss

    let state: AppState
    @ObservedObject var hk: HealthKitManager
    let onSave: () -> Void

    @StateObject private var viewModel = StepEnjoyViewModel()
    @State private var displayedDelta: Int = 0
    @State private var isResetConfirmShown: Bool = false

    private var currentPetName: String {
        PetMaster.all.first(where: { $0.id == state.currentPetID })?.name ?? "ペット"
    }

    private var currentPetAssetName: String {
        PetMaster.assetName(for: state.currentPetID)
    }

    private var isDailyMaxReached: Bool {
        state.stepEnjoyDailyRewardCount >= StepEnjoyRewardPolicy.dailyRewardMaxCount
    }

    private var stepsUntilNext: Int {
        max(0, StepEnjoyRewardPolicy.rewardStepThreshold - (max(0, state.stepEnjoyDailyRewardStepBank) % StepEnjoyRewardPolicy.rewardStepThreshold))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("現在お世話中")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Image(currentPetAssetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                            Text(currentPetName)
                                .font(.title3.bold())
                        }
                    }

                    VStack(spacing: 8) {
                        Text("前回から")
                            .font(.headline)
                        Text("+\(displayedDelta) 歩")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    summaryRow(title: "今日の総歩数", value: viewModel.dayTotalSteps)
                    summaryRow(title: "今週の総歩数", value: viewModel.weekTotalSteps)
                    summaryRow(title: "この機能内の累計", value: state.stepEnjoyTotalSteps)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("報酬")
                            .font(.headline)
                        Button("報酬獲得") {
                            viewModel.claimReward(state: state, save: onSave)
                            Haptics.notify(.success)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.claimableCount < 1 || viewModel.isClaiming || isDailyMaxReached)

                        Text("本日の獲得数: \(state.stepEnjoyDailyRewardCount) / \(StepEnjoyRewardPolicy.dailyRewardMaxCount)")
                        Text("次の報酬まで: \(stepsUntilNext)歩")
                        Text("獲得可能: \(viewModel.claimableCount)個")
                            .foregroundStyle(.secondary)

                        if isDailyMaxReached {
                            Text("今日はこれ以上獲得できません")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        } else if viewModel.claimableCount < 1 {
                            Text("2000歩ごとに1個獲得できます")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let food = viewModel.lastGrantedFood {
                            HStack {
                                Image(food.assetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 34, height: 34)
                                Text("\(food.name) を獲得！")
                                    .bold()
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("直近10回ログ")
                            .font(.headline)
                        ForEach(viewModel.logs) { log in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("+\(log.delta)歩 / 累計\(log.totalAfter)歩")
                                Text("今日\(log.dayTotal)歩・今週\(log.weekTotal)歩")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    HStack {
                        Button("更新") {
                            Task { await refresh() }
                        }
                        .buttonStyle(.bordered)

                        Button("リセット") {
                            isResetConfirmShown = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("おたのしみ散歩")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task {
            viewModel.loadCached(state: state)
            await refresh()
        }
        .confirmationDialog("おたのしみ散歩の履歴をリセットしますか？", isPresented: $isResetConfirmShown) {
            Button("リセット", role: .destructive) {
                viewModel.resetProgress(state: state, save: onSave)
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func refresh() async {
        await viewModel.refresh(state: state, hk: hk, save: onSave)
        await animateDelta(target: state.stepEnjoyLastDeltaSteps)
    }

    private func animateDelta(target: Int) async {
        let safeTarget = max(0, target)
        if safeTarget == 0 {
            displayedDelta = 0
            return
        }
        displayedDelta = 0
        let step = max(1, safeTarget / 25)
        while displayedDelta < safeTarget {
            displayedDelta = min(safeTarget, displayedDelta + step)
            Haptics.tap(style: .soft)
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    @ViewBuilder
    private func summaryRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)歩")
                .bold()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
