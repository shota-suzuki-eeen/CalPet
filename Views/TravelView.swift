import SwiftUI
import SpriteKit
import SwiftData

struct TravelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let state: AppState
    @ObservedObject var hk: HealthKitManager

    @StateObject private var viewModel: TravelViewModel
    @State private var scene = TravelScene(size: CGSize(width: 420, height: 180))
    @Namespace private var deltaNamespace

    @AppStorage("travel.hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("travel.balancePreset") private var presetRaw: String = TravelBalancePreset.standard.rawValue

    init(state: AppState, hk: HealthKitManager) {
        self.state = state
        self.hk = hk
        _viewModel = StateObject(wrappedValue: TravelViewModel(stepProvider: HealthKitStepProvider(hk: hk)))
    }

    private var preset: TravelBalancePreset {
        get { TravelBalancePreset(rawValue: presetRaw) ?? .standard }
        nonmutating set { presetRaw = newValue.rawValue }
    }

    private var petAssetName: String {
        let raw = PetMaster.assetName(for: state.currentPetID)
        return raw.isEmpty ? "purpor" : raw
    }

    var body: some View {
        let theme = TravelThemeProvider().theme()

        ZStack {
            theme.gradient.ignoresSafeArea()
            Circle().fill(.white.opacity(0.12)).frame(width: 180).offset(x: -130, y: -280)
            Circle().fill(.white.opacity(0.1)).frame(width: 130).offset(x: 150, y: -220)

            VStack(spacing: 14) {
                topBar(theme: theme)
                statsCard
                sceneCard
                controlCard
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .task { await refresh() }
        .onAppear {
            scene.scaleMode = .resizeFill
            scene.configureCharacter(assetName: petAssetName)
            scene.setProgress(CGFloat(viewModel.progress), animated: false, duration: 0, reduceMotion: reduceMotion)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refresh() }
        }
    }

    private func topBar(theme: TravelTheme) -> some View {
        HStack {
            Text("旅モード  \(theme.label)")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.25), in: Circle())
            }
        }
    }

    private var statsCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("今週の歩数")
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("\(viewModel.displayedWeeklySteps) 歩")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .matchedGeometryEffect(id: "weeklySteps", in: deltaNamespace)
            }

            if viewModel.isDeltaVisible {
                HStack {
                    Spacer()
                    Text("+\(viewModel.deltaSteps) 歩")
                        .font(.headline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .matchedGeometryEffect(id: "weeklySteps", in: deltaNamespace)
                        .opacity(viewModel.absorbDeltaIntoTotal ? 0 : 1)
                }
                .transition(.opacity)
            }

            ProgressView(value: min(1, Double(viewModel.latestWeeklySteps) / Double(max(1, preset.weeklyGoalSteps))))
                .tint(.white)

            Text("ゴール: \(preset.weeklyGoalSteps) 歩")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))

            Text("\(viewModel.message)")
                .font(.footnote)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
    }

    private var sceneCard: some View {
        VStack(spacing: 10) {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack {
                Text("満足度")
                Spacer()
                Text("\(viewModel.satisfaction)/\(preset.maxSatisfaction)")
            }
            .foregroundStyle(.white)

            if !viewModel.rewards.isEmpty || viewModel.hiddenRewardCount > 0 {
                rewardSection
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FoodCatalog.all.filter { state.foodCount(foodId: $0.id) > 0 }.prefix(6)) { food in
                        Button {
                            viewModel.recoverByFood(foodId: food.id, appState: state, preset: preset, save: save)
                        } label: {
                            VStack(spacing: 4) {
                                Image(food.assetName).resizable().scaledToFit().frame(width: 34, height: 34)
                                Text("x\(state.foodCount(foodId: food.id))").font(.caption2)
                            }
                            .padding(8)
                            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
    }

    private var rewardSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(viewModel.rewards, id: \.id) { food in
                Text("🎁 \(food.name) を獲得")
                    .font(.footnote)
                    .foregroundStyle(.white)
            }
            if viewModel.hiddenRewardCount > 0 {
                Text("ほか \(viewModel.hiddenRewardCount) 件")
                    .font(.footnote.bold())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlCard: some View {
        VStack(spacing: 10) {
            Toggle("ハプティクス", isOn: $hapticsEnabled)
                .tint(.green)
                .foregroundStyle(.white)

            Picker("バランス", selection: Binding(get: { preset }, set: { preset = $0 })) {
                ForEach(TravelBalancePreset.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("更新") { Task { await refresh() } }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Text("42.195kmの\(Int((Double(viewModel.latestWeeklySteps) * 0.0008 / 42.195) * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(14)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
    }

    private func refresh() async {
        await viewModel.refresh(
            appState: state,
            preset: preset,
            hapticsEnabled: hapticsEnabled,
            reduceMotion: reduceMotion,
            onProgressAnimate: { value, duration in
                scene.setProgress(CGFloat(value), animated: true, duration: duration, reduceMotion: reduceMotion)
            },
            save: save
        )
    }

    private func save() {
        try? modelContext.save()
    }
}
