import SwiftUI

struct StepEnjoyView: View {
    @Environment(\.dismiss) private var dismiss

    let state: AppState
    @ObservedObject var hk: HealthKitManager
    let onSave: () -> Void

    @StateObject private var viewModel = StepEnjoyViewModel()

    @State private var animatedDelta: Int = 0
    @State private var bgOffset: CGFloat = 0
    @State private var characterBounce = false

    private var currentPetName: String {
        PetMaster.all.first(where: { $0.id == state.currentPetID })?.name ?? "ペット"
    }

    private var currentPetAsset: String {
        PetMaster.assetName(for: state.currentPetID)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                movingBackground(width: geo.size.width)

                VStack(spacing: 16) {
                    HStack {
                        Text("おたのしみ散歩")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Button("とじる") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 20)

                    Text("いまお世話中: \(currentPetName)")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.95))

                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 280, height: 280)

                        Image(currentPetAsset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .offset(y: characterBounce ? -8 : 8)
                            .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: characterBounce)
                    }

                    Text("前回から +\(animatedDelta)歩")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.yellow)
                        .monospacedDigit()

                    summaryCard
                    rewardSection

                    Button("更新") {
                        Task { await refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)

                    Spacer(minLength: 12)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea()
        .task { await refresh() }
        .onAppear { characterBounce = true }
    }

    private var summaryCard: some View {
        VStack(spacing: 10) {
            metricRow(title: "今日の総歩数", value: viewModel.dayTotalSteps)
            metricRow(title: "今週の総歩数", value: viewModel.weekTotalSteps)
            metricRow(title: "この機能内の累計", value: state.stepEnjoyTotalSteps)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private var rewardSection: some View {
        let nextRemaining = StepEnjoyRewardPolicy.nextRewardRemainingSteps(
            bank: state.stepEnjoyDailyRewardStepBank,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        return VStack(alignment: .leading, spacing: 8) {
            Text("報酬")
                .font(.title3.bold())
            Text("本日の獲得数: \(state.stepEnjoyDailyRewardCount)/\(StepEnjoyRewardPolicy.dailyRewardMaxCount)")
            if state.stepEnjoyDailyRewardCount >= StepEnjoyRewardPolicy.dailyRewardMaxCount {
                Text("今日はこれ以上獲得できません")
                    .foregroundStyle(.orange)
            } else {
                Text("次の報酬まであと \(nextRemaining) 歩")
            }

            Button("報酬獲得") {
                viewModel.claimReward(state: state, save: onSave)
                Haptics.notify(.success)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.claimableCount < 1 || viewModel.isClaiming)

            if let foodName = viewModel.gainedFoodName {
                Text("🎁 \(foodName) を獲得！")
                    .font(.headline)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func metricRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)歩")
                .bold()
                .monospacedDigit()
        }
        .foregroundStyle(.white)
    }

    private func movingBackground(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            scenicPanel(width: width)
            scenicPanel(width: width)
        }
        .offset(x: bgOffset)
    }

    private func scenicPanel(width: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.33, green: 0.72, blue: 0.98), Color(red: 0.55, green: 0.86, blue: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                Spacer()
                Rectangle()
                    .fill(Color(red: 0.36, green: 0.73, blue: 0.46))
                    .frame(height: 140)
            }

            HStack(spacing: 28) {
                ForEach(0..<12, id: \.self) { _ in
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.54, blue: 0.26))
                            .frame(width: 30, height: 30)
                        Rectangle()
                            .fill(Color(red: 0.30, green: 0.22, blue: 0.12))
                            .frame(width: 6, height: 34)
                    }
                    .offset(y: 150)
                }
            }
        }
        .frame(width: width)
        .clipped()
    }

    private func refresh() async {
        viewModel.gainedFoodName = nil
        await viewModel.refresh(state: state, hk: hk, save: onSave)
        runCountUp(to: viewModel.deltaSteps)

        if viewModel.deltaSteps > 0 {
            Haptics.tap(style: .light)
            withAnimation(.linear(duration: 1.2)) {
                bgOffset = -UIScreen.main.bounds.width
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                bgOffset = 0
            }
        }
    }

    private func runCountUp(to target: Int) {
        animatedDelta = 0
        guard target > 0 else { return }

        let ticks = 24
        let interval = 0.02
        for index in 1...ticks {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(index)) {
                animatedDelta = Int(Double(target) * (Double(index) / Double(ticks)))
            }
        }
    }
}
