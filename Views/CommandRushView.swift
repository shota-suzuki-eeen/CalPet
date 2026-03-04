import SwiftUI

struct CommandRushView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let state: AppState

    @StateObject private var viewModel = CommandRushViewModel()
    @State private var showSettings = false

    private var petAssetName: String {
        PetMaster.assetName(for: state.currentPetID)
    }

    var body: some View {
        ZStack {
            stageBackground
                .ignoresSafeArea()

            VStack(spacing: 14) {
                topHUD

                commandPanel

                Spacer(minLength: 0)

                danceArea

                Spacer(minLength: 0)

                inputPad
            }
            .padding()

            if viewModel.showGhostGuide {
                ghostGuide
            }

            if viewModel.phase == .cleared || viewModel.phase == .gameOver {
                resultOverlay
            }
        }
        .overlay {
            viewModel.flashColor.ignoresSafeArea()
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
                .presentationDetents([.medium])
        }
        .onAppear {
            viewModel.configure(reduceMotion: reduceMotion)
            viewModel.startGame()
        }
        .onChange(of: reduceMotion) { _, newValue in
            viewModel.configure(reduceMotion: newValue)
        }
        .onDisappear {
            viewModel.stopGame()
        }
    }

    private var stageBackground: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let pulse = CGFloat(0.5 + (sin(phase * 3) + 1) * 0.25)
                let comboBoost = CGFloat(min(viewModel.combo, 20)) * 0.01
                let alpha = reduceMotion ? 0.16 : (0.18 + comboBoost)

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.black,
                            Color.purple.opacity(alpha + pulse * 0.12),
                            Color.blue.opacity(alpha)
                        ]),
                        startPoint: CGPoint(x: size.width / 2, y: 0),
                        endPoint: CGPoint(x: size.width / 2, y: size.height)
                    )
                )

                for i in 0..<18 {
                    let x = CGFloat(i) / 18 * size.width
                    let y = size.height * 0.2 + CGFloat(sin(phase * 2 + Double(i))) * (reduceMotion ? 2 : 12)
                    let rect = CGRect(x: x, y: y, width: 4, height: 4)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.35 + comboBoost)))
                }
            }
        }
    }

    private var topHUD: some View {
        HStack {
            statChip(title: "SCORE", value: "\(viewModel.score)")
            statChip(title: "COMBO", value: "x\(viewModel.combo)")
            statChip(title: "LIFE", value: String(repeating: "♥", count: max(0, viewModel.lives)))
            statChip(title: "LV", value: "\(viewModel.level)")

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.white.opacity(0.16))
                        .clipShape(Circle())
                }

                Text(viewModel.bestScoreText())
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var commandPanel: some View {
        VStack(spacing: 10) {
            if let command = viewModel.currentCommand {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 90, height: 90)

                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 90, height: 90)

                    VStack(spacing: 3) {
                        Image(systemName: command.kind.symbolName)
                            .font(.title.bold())
                        Text(command.kind.title)
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                }
            } else {
                Text("READY")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }

    private var danceArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(height: 260)

            HStack(spacing: 22) {
                speakerView
                petView
                speakerView
            }
        }
    }

    private var speakerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
            RoundedRectangle(cornerRadius: 5)
                .fill(.white.opacity(0.8))
                .frame(width: 12, height: 45 + CGFloat(min(viewModel.combo, 12)) * (reduceMotion ? 0.5 : 2))
                .animation(.easeInOut(duration: 0.2), value: viewModel.combo)
        }
        .frame(width: 46)
    }

    private var petView: some View {
        VStack(spacing: 8) {
            Image(petAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .scaleEffect(viewModel.danceTransform.scale)
                .rotationEffect(.degrees(viewModel.danceTransform.rotation))
                .offset(viewModel.danceTransform.offset)
                .opacity(viewModel.danceTransform.opacity)

            Text("いっしょにダンス！")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var inputPad: some View {
        Color.clear
            .frame(height: 160)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.handleTap()
            }
            .gesture(
                DragGesture(minimumDistance: 16)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if abs(dx) > abs(dy) {
                            viewModel.handleSwipe(dx > 0 ? .swipeRight : .swipeLeft)
                        } else {
                            viewModel.handleSwipe(dy > 0 ? .swipeDown : .swipeUp)
                        }
                    }
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [6]))
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white.opacity(0.05))
                    )
                    .overlay(alignment: .center) {
                        Label("Tap / Swipe", systemImage: "hand.point.up.left.fill")
                            .foregroundStyle(.white.opacity(0.9))
                    }
            }
    }

    private var ghostGuide: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "hand.point.up.left.fill")
                Text(viewModel.ghostGuideKind == .tap ? "ポンッ" : "スッ")
            }
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                if viewModel.ghostGuideKind != .tap {
                    Image(systemName: viewModel.ghostGuideKind.symbolName)
                        .offset(x: 44)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .padding(.bottom, 190)
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(viewModel.phase == .cleared ? "CLEAR!" : "GAME OVER")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(viewModel.phase == .cleared ? .yellow : .white)
                Text("SCORE: \(viewModel.score)")
                    .font(.title3.bold())
                if let result = viewModel.result {
                    Text("BEST: \(result.bestScore) / TODAY: \(result.bestToday)")
                        .font(.subheadline)
                }

                HStack(spacing: 12) {
                    Button("もう一度") {
                        viewModel.startGame()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("閉じる") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding()
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Toggle("サウンド", isOn: $viewModel.soundEnabled)
                Toggle("触覚", isOn: $viewModel.hapticsEnabled)
            }
            .navigationTitle("ゲーム設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { showSettings = false }
                }
            }
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.subheadline.bold()).foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
