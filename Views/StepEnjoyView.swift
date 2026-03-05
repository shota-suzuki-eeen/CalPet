import SwiftUI

struct StepEnjoyView: View {
    @Environment(\.dismiss) private var dismiss

    let state: AppState
    @ObservedObject var hk: HealthKitManager
    let onSave: () -> Void

    @StateObject private var viewModel = StepEnjoyViewModel()
    @State private var displayedDelta: Int = 0
    @State private var isResetConfirmShown: Bool = false
    @State private var walkPhase: Double = 0
    @State private var animateScene: Bool = false

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
            ZStack {
                StepEnjoyParallaxBackground(isMoving: animateScene)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 10) {
                            Text("おたのしみ散歩")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text("現在お世話中: \(currentPetName)")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.95))
                        }
                        .padding(.top, 8)

                        characterStage

                        HStack(spacing: 12) {
                            statPill(title: "今日", value: viewModel.dayTotalSteps)
                            statPill(title: "今週", value: viewModel.weekTotalSteps)
                            statPill(title: "累計", value: state.stepEnjoyTotalSteps)
                        }

                        rewardSection

                        HStack {
                            Button("更新") {
                                Task { await refresh() }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("リセット") {
                                isResetConfirmShown = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                        }
                        .padding(.bottom, 14)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            viewModel.loadCached(state: state)
            await refresh()
        }
        .confirmationDialog("歩数進捗をリセットしますか？", isPresented: $isResetConfirmShown) {
            Button("リセット", role: .destructive) {
                viewModel.resetProgress(state: state, save: onSave)
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var characterStage: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.4), lineWidth: 1))
                    .frame(height: 280)

                VStack(spacing: 10) {
                    Image(currentPetAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 190)
                        .rotationEffect(.degrees(animateScene ? 1.5 : -1.5))
                        .offset(y: animateScene ? -6 : 4)
                        .scaleEffect(animateScene ? 1.02 : 0.98)
                        .offset(x: sin(walkPhase) * (animateScene ? 10 : 0))
                        .animation(.easeInOut(duration: 0.22), value: animateScene)

                    Text("前回から +\(displayedDelta) 歩")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }
        }
    }

    private var rewardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("報酬")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Button("報酬獲得") {
                viewModel.claimReward(state: state, save: onSave)
                Haptics.notify(.success)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.claimableCount < 1 || viewModel.isClaiming || isDailyMaxReached)

            Text("本日の獲得数: \(state.stepEnjoyDailyRewardCount) / \(StepEnjoyRewardPolicy.dailyRewardMaxCount)")
                .foregroundStyle(.white)
            Text("次の報酬まで: \(stepsUntilNext)歩")
                .foregroundStyle(.white)
            Text("獲得可能: \(viewModel.claimableCount)個")
                .foregroundStyle(.white.opacity(0.9))

            if isDailyMaxReached {
                Text("今日はこれ以上獲得できません")
                    .font(.footnote)
                    .foregroundStyle(.yellow)
            } else if viewModel.claimableCount < 1 {
                Text("2000歩ごとに1個獲得できます")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let food = viewModel.lastGrantedFood {
                HStack {
                    Image(food.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ごはんをゲット！")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(food.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.green.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func refresh() async {
        await viewModel.refresh(state: state, hk: hk, save: onSave)
        await animateDelta(target: state.stepEnjoyLastDeltaSteps)
    }

    private func animateDelta(target: Int) async {
        let safeTarget = max(0, target)
        displayedDelta = 0
        guard safeTarget > 0 else {
            animateScene = false
            return
        }

        animateScene = true
        let step = max(1, safeTarget / 40)
        while displayedDelta < safeTarget {
            displayedDelta = min(safeTarget, displayedDelta + step)
            walkPhase += 0.35
            Haptics.tap(style: .soft)
            try? await Task.sleep(nanoseconds: 22_000_000)
        }

        try? await Task.sleep(nanoseconds: 350_000_000)
        animateScene = false
    }

    @ViewBuilder
    private func statPill(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
            Text("\(value)歩")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct StepEnjoyParallaxBackground: View {
    let isMoving: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.17, green: 0.44, blue: 0.88), Color(red: 0.14, green: 0.70, blue: 0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                movingLayer(color: .white.opacity(0.16), y: geo.size.height * 0.34, height: 26, speed: 42, width: geo.size.width)
                movingLayer(color: .mint.opacity(0.25), y: geo.size.height * 0.58, height: 38, speed: 80, width: geo.size.width)
                movingLayer(color: .green.opacity(0.30), y: geo.size.height * 0.82, height: 60, speed: 120, width: geo.size.width)
            }
            .onAppear { phase = 0 }
            .task(id: isMoving) {
                if isMoving {
                    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                        phase = 300
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.25)) {
                        phase = 0
                    }
                }
            }
        }
    }

    private func movingLayer(color: Color, y: CGFloat, height: CGFloat, speed: CGFloat, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(color).frame(width: width)
            Rectangle().fill(color).frame(width: width)
            Rectangle().fill(color).frame(width: width)
        }
        .frame(width: width * 3, height: height)
        .offset(x: -(phase * (speed / 120)), y: y)
    }
}
