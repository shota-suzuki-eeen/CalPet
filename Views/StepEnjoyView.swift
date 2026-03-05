//
//  StepEnjoyView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/03/05.
//

import SwiftUI

struct StepEnjoyView: View {
    @Environment(\.dismiss) private var dismiss

    let state: AppState
    @ObservedObject var hk: HealthKitManager
    let onSave: () -> Void

    @StateObject private var viewModel = StepEnjoyViewModel()

    @State private var animatedDelta: Int = 0
    @State private var bgOffset: CGFloat = 0

    // ✅ 歩行中だけ揺らす
    @State private var isWalking = false
    @State private var stopWalkingWorkItem: DispatchWorkItem?

    private var currentPetName: String {
        PetMaster.all.first(where: { $0.id == state.currentPetID })?.name ?? "ペット"
    }

    private var currentPetAsset: String {
        PetMaster.assetName(for: state.currentPetID)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let safeH = max(1, h)

            // ---- 前景の収まり計算（スクロールなし前提） ----
            let headerH: CGFloat = 56
            let subtitleH: CGFloat = 28
            let deltaH: CGFloat = 44
            let buttonH: CGFloat = 44
            let verticalGaps: CGFloat = 10 + 8 + 8 + 10 + 8

            let minCardsH: CGFloat = max(180, min(210, safeH * 0.25))

            let remainingForCharacter = safeH - (headerH + subtitleH + deltaH + buttonH + minCardsH + verticalGaps)
            let characterBoxH = max(130, min(260, remainingForCharacter))

            let circleSize = min(w * 0.58, characterBoxH * 0.95)
            let imageSize = circleSize * 0.78

            ZStack {
                // ✅ 背景は画面サイズに固定してレイアウトを押し出させない
                movingBackground(width: w, height: h)
                    .frame(width: w, height: h)
                    .ignoresSafeArea()
                    .clipped()

                VStack(spacing: 10) {
                    header
                        .frame(height: headerH)

                    Text("いまお世話中: \(currentPetName)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 18)
                        .frame(height: subtitleH)

                    // ✅ キャラは常に中央。歩行中だけ上下に揺れる
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: circleSize, height: circleSize)

                        Image(currentPetAsset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageSize, height: imageSize)
                            .offset(y: isWalking ? -6 : 0)
                            // ✅ アニメは「offset」だけに限定して適用（レイアウト全体を巻き込まない）
                            .animation(isWalking ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true) : .default,
                                       value: isWalking)
                    }
                    .frame(height: characterBoxH)
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text("前回から +\(animatedDelta)歩")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(.yellow)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 18)
                        .frame(height: deltaH)

                    cardsSection
                        .padding(.horizontal, 18)
                        .frame(minHeight: minCardsH)

                    Button("更新") {
                        Task { await refresh(containerWidth: w) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                    .controlSize(.regular)
                    .frame(height: buttonH)

                    Color.clear.frame(height: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaPadding(.top, 6)
                .safeAreaPadding(.bottom, 8)
            }
            .frame(width: w, height: h, alignment: .top)
            .clipped()
        }
        .task { await refresh(containerWidth: UIScreen.main.bounds.width) }
        .onDisappear {
            // 念のため後始末
            stopWalkingWorkItem?.cancel()
            stopWalkingWorkItem = nil
            stopWalkingImmediately()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("おたのしみ散歩")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Button("とじる") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Cards

    private var cardsSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                summaryCardCompact
                    .frame(maxWidth: .infinity)
                rewardCardCompact
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 10) {
                summaryCardCompact
                rewardCardCompact
            }
        }
    }

    private var summaryCardCompact: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("歩数")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))

            metricRowCompact(title: "今日の総歩数", value: viewModel.dayTotalSteps)
            metricRowCompact(title: "今週の総歩数", value: viewModel.weekTotalSteps)
            metricRowCompact(title: "この機能内の累計", value: state.stepEnjoyTotalSteps)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var rewardCardCompact: some View {
        let nextRemaining = StepEnjoyRewardPolicy.nextRewardRemainingSteps(
            bank: state.stepEnjoyDailyRewardStepBank,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        let maxCount = StepEnjoyRewardPolicy.dailyRewardMaxCount
        let claimed = state.stepEnjoyDailyRewardCount
        let canClaim = (claimed < maxCount) && (viewModel.claimableCount >= 1) && !viewModel.isClaiming

        return VStack(alignment: .leading, spacing: 8) {
            Text("報酬")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))

            HStack {
                Text("本日の獲得数")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                Text("\(claimed)/\(maxCount)")
                    .monospacedDigit()
                    .bold()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))

            if claimed >= maxCount {
                Text("今日はこれ以上獲得できません")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } else {
                Text("次の報酬まであと \(nextRemaining) 歩")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                Button("報酬獲得") {
                    viewModel.claimReward(state: state, save: onSave)
                    Haptics.notify(.success)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canClaim)

                Spacer(minLength: 0)
            }

            if let foodName = viewModel.gainedFoodName {
                Text("🎁 \(foodName) を獲得！")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
    }

    private func metricRowCompact(title: String, value: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Text("\(value)歩")
                .bold()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
    }

    // MARK: - Background

    private func movingBackground(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            scenicPanel(width: width, height: height)
            scenicPanel(width: width, height: height)
        }
        .frame(width: width * 2, height: height)
        .offset(x: bgOffset)
        .clipped()
    }

    private func scenicPanel(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.33, green: 0.72, blue: 0.98), Color(red: 0.55, green: 0.86, blue: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 0)
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 140 - 34)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // MARK: - Actions

    private func refresh(containerWidth: CGFloat) async {
        viewModel.gainedFoodName = nil
        await viewModel.refresh(state: state, hk: hk, save: onSave)

        let delta = viewModel.deltaSteps
        runCountUp(to: delta)

        if delta > 0 {
            // ✅ 歩数増加時だけ「歩いてる」演出
            startWalking(duration: 1.2)

            Haptics.tap(style: .light)
            withAnimation(.linear(duration: 1.2)) {
                bgOffset = -containerWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                bgOffset = 0
            }
        } else {
            // ✅ 増えてない時は必ず静止
            stopWalkingImmediately()
        }
    }

    private func startWalking(duration: TimeInterval) {
        stopWalkingWorkItem?.cancel()

        // 開始
        isWalking = true

        // 停止予約
        let item = DispatchWorkItem {
            stopWalkingImmediately()
        }
        stopWalkingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    private func stopWalkingImmediately() {
        // repeatForever を確実に止めるため、アニメーション無しで state を戻す
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            isWalking = false
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
