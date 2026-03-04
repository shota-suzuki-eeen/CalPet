import SwiftUI

struct CommandRushView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var viewModel: CommandRushViewModel
    @State private var petScale: CGFloat = 1
    @State private var petYOffset: CGFloat = 0
    @State private var petRotation: Double = 0

    init(state: AppState) {
        let petID = state.currentPetID
        let asset = PetMaster.assetName(for: petID)
        _viewModel = StateObject(wrappedValue: CommandRushViewModel(petID: petID, petAssetName: asset))
    }

    var body: some View {
        ZStack {
            animatedBackground

            VStack(spacing: 16) {
                header
                Spacer(minLength: 4)
                petArea
                commandArea
                Spacer()
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)

            GameInputSurface { input in
                viewModel.handleInput(input)
            }
            .ignoresSafeArea()

            if viewModel.showGuide, let kind = viewModel.guideKind {
                ghostGuide(kind: kind)
            }

            if viewModel.phase == .cleared || viewModel.phase == .gameOver {
                resultOverlay
            }
        }
        .statusBarHidden(true)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onChange(of: viewModel.didHitCommand) { _, value in
            if value { playPetSuccessAnimation() }
        }
        .onChange(of: viewModel.didMissCommand) { _, value in
            if value { playPetMissAnimation() }
        }
        .onChange(of: viewModel.didClear) { _, value in
            if value { playPetClearAnimation() }
        }
    }

    private var animatedBackground: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let colors = [Color(red: 0.10, green: 0.15, blue: 0.30), Color(red: 0.22, green: 0.07, blue: 0.30)]
                let rect = CGRect(origin: .zero, size: size)
                ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))

                for i in 0..<16 {
                    let phase = t + Double(i) * 0.42
                    let x = (sin(phase * 0.8) * 0.5 + 0.5) * size.width
                    let y = (cos(phase * 0.6 + Double(i)) * 0.5 + 0.5) * size.height
                    let r = 2 + CGFloat((sin(phase) + 1) * 3)
                    let alpha = 0.07 + (sin(phase * 1.7) + 1) * 0.04
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(alpha)))
                }
            }
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            Text("SCORE \(viewModel.score)")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .scaleEffect(viewModel.didHitCommand ? 1.1 : 1)
            Spacer()
            lifeView
        }
    }

    private var lifeView: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < viewModel.lives ? "heart.fill" : "heart")
                    .foregroundStyle(idx < viewModel.lives ? .red : .white.opacity(0.35))
            }
        }
        .font(.system(size: 18))
    }

    private var petArea: some View {
        Image(viewModel.petAssetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 220)
            .scaleEffect(petScale)
            .rotationEffect(.degrees(petRotation))
            .offset(y: petYOffset)
            .brightness(viewModel.didHitCommand ? 0.08 : 0)
            .animation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.24, dampingFraction: 0.6), value: petScale)
    }

    private var commandArea: some View {
        VStack(spacing: 10) {
            if let command = viewModel.currentCommand {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 10)
                        .frame(width: 132, height: 132)

                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(command.kind.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 132, height: 132)

                    Image(systemName: command.kind.symbolName)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
            } else {
                Text(viewModel.phase == .playing ? "NEXT" : "READY")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(height: 132)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            statBadge(title: "COMBO", value: "\(viewModel.combo)")
            statBadge(title: "LV", value: "\(viewModel.level)")
            statBadge(title: "TODAY BEST", value: "\(viewModel.bestToday)")
        }
    }

    private func statBadge(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 10, weight: .semibold))
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func ghostGuide(kind: CommandKind) -> some View {
        VStack(spacing: 6) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 36, weight: .bold))
            Text("Hint")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity)
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(viewModel.phase == .cleared ? "CLEAR" : "GAME OVER")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(viewModel.phase == .cleared ? .yellow : .white)

                Text("Score \(viewModel.score)")
                    .font(.title3).bold().monospacedDigit()
                    .foregroundStyle(.white)

                Text("Today Best \(viewModel.bestToday) / All Best \(viewModel.bestAllTime)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))

                HStack(spacing: 10) {
                    Button("もう一回") { viewModel.start() }
                        .buttonStyle(.borderedProminent)
                    Button("とじる") { dismiss() }
                        .buttonStyle(.bordered)
                }

                Toggle("Sound", isOn: $viewModel.soundEnabled)
                    .toggleStyle(.switch)
                    .foregroundStyle(.white)
                Toggle("Haptics", isOn: $viewModel.hapticsEnabled)
                    .toggleStyle(.switch)
                    .foregroundStyle(.white)
                Toggle("Shake Command", isOn: $viewModel.shakeEnabled)
                    .toggleStyle(.switch)
                    .foregroundStyle(.white)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 24)
        }
    }

    private func playPetSuccessAnimation() {
        guard !reduceMotion else { return }
        petScale = 1.12
        petYOffset = -16
        petRotation = 4
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            petScale = 1
            petYOffset = 0
            petRotation = 0
        }
    }

    private func playPetMissAnimation() {
        guard !reduceMotion else { return }
        petScale = 0.9
        petYOffset = 18
        petRotation = -6
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            petScale = 1
            petYOffset = 0
            petRotation = 0
        }
    }

    private func playPetClearAnimation() {
        guard !reduceMotion else { return }
        petScale = 1.2
        petYOffset = -24
        petRotation = 14
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            petScale = 1
            petYOffset = 0
            petRotation = 0
        }
    }
}
