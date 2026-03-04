import SwiftUI

struct MiniGamesView: View {
    let state: AppState

    @State private var selectedGame: MiniGameKind = .catch

    private var petAssetName: String {
        PetMaster.assetName(for: state.currentPetID)
    }

    private var petName: String {
        PetMaster.all.first(where: { $0.id == state.currentPetID })?.name ?? "ペット"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.15, blue: 0.30), Color(red: 0.06, green: 0.08, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(petAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .padding(7)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("ミニゲーム")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("\(petName)と遊ぶ")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                Picker("ミニゲーム", selection: $selectedGame) {
                    ForEach(MiniGameKind.allCases) { game in
                        Text(game.title).tag(game)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                Group {
                    switch selectedGame {
                    case .catch:
                        CatchRushGameView(petAssetName: petAssetName)
                    case .dodge:
                        JumpDodgeGameView(petAssetName: petAssetName)
                    case .protect:
                        GuardTapGameView(petAssetName: petAssetName)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .padding(.top, 8)
        }
        .navigationTitle("ミニゲーム")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum MiniGameKind: String, CaseIterable, Identifiable {
    case catch
    case dodge
    case protect

    var id: String { rawValue }

    var title: String {
        switch self {
        case .catch: return "キャッチ"
        case .dodge: return "よける"
        case .protect: return "まもる"
        }
    }
}

private struct GamePanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 180)
                    .blur(radius: 24)
                    .offset(x: -40, y: -50)
            }
    }
}

private struct CatchRushGameView: View {
    let petAssetName: String

    private let goalScore: Int = 12

    @State private var playerX: CGFloat = 0.5
    @State private var score: Int = 0
    @State private var items: [FallingItem] = []
    @State private var isRunning: Bool = true

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let playerY = size.height - 92
            let playerWidth: CGFloat = 84

            ZStack {
                GamePanelBackground()

                ForEach(items) { item in
                    CatchItemView(kindIsGood: item.kind == .good)
                        .frame(width: 34, height: 34)
                        .position(x: item.x * size.width, y: item.y)
                }

                VStack(spacing: 8) {
                    HStack {
                        Label("\(score)/\(goalScore)", systemImage: "star.circle.fill")
                        Spacer()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)

                    ProgressView(value: min(Double(score), Double(goalScore)), total: Double(goalScore))
                        .tint(.yellow)
                }
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .top)

                Image(petAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: playerWidth, height: playerWidth)
                    .position(x: playerX * size.width, y: playerY)
                    .shadow(color: .white.opacity(0.15), radius: 14)

                if !isRunning {
                    GameResultOverlay(
                        title: score >= goalScore ? "クリア！" : "ざんねん",
                        tint: score >= goalScore ? .green : .pink,
                        buttonTitle: "もう一回",
                        onRetry: reset
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isRunning else { return }
                        playerX = max(0.1, min(0.9, value.location.x / max(size.width, 1)))
                    }
            )
            .onReceive(timer) { _ in
                guard isRunning else { return }

                if Double.random(in: 0...1) < 0.09 {
                    items.append(
                        FallingItem(
                            x: CGFloat.random(in: 0.1...0.9),
                            y: -26,
                            speed: CGFloat.random(in: 3.1...4.8),
                            kind: Double.random(in: 0...1) < 0.75 ? .good : .bad
                        )
                    )
                }

                for idx in items.indices {
                    items[idx].y += items[idx].speed
                }

                let playerRect = CGRect(x: playerX * size.width - playerWidth / 2, y: playerY - playerWidth / 2, width: playerWidth, height: playerWidth)

                items.removeAll { item in
                    let itemRect = CGRect(x: item.x * size.width - 16, y: item.y - 16, width: 32, height: 32)
                    if itemRect.intersects(playerRect) {
                        score += item.kind == .good ? 1 : -1
                        score = max(0, score)
                        if score >= goalScore {
                            isRunning = false
                        }
                        return true
                    }
                    return item.y > size.height + 44
                }
            }
        }
    }

    private func reset() {
        playerX = 0.5
        score = 0
        items = []
        isRunning = true
    }

    private struct FallingItem: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var speed: CGFloat
        var kind: ItemKind
    }

    private enum ItemKind {
        case good
        case bad
    }
}

private struct CatchItemView: View {
    let kindIsGood: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(kindIsGood ? Color.yellow.opacity(0.9) : Color.pink.opacity(0.9))
            Image(systemName: kindIsGood ? "star.fill" : "flame.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
    }
}

private struct JumpDodgeGameView: View {
    let petAssetName: String

    private let goalPassedCount: Int = 18

    @State private var playerY: CGFloat = 0
    @State private var velocityY: CGFloat = 0
    @State private var lives: Int = 3
    @State private var passedCount: Int = 0
    @State private var obstacles: [SideObstacle] = []
    @State private var isRunning: Bool = true

    private let gravity: CGFloat = 0.72
    private let jumpPower: CGFloat = -11.5
    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let groundY = size.height - 74
            let playerX = size.width * 0.24
            let characterSize: CGFloat = 86

            ZStack {
                GamePanelBackground()

                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(height: 8)
                    .padding(.horizontal, 18)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 56)

                ForEach(obstacles) { obstacle in
                    RockObstacleView()
                        .frame(width: obstacle.width, height: obstacle.height)
                        .position(x: obstacle.x, y: groundY - obstacle.height / 2)
                }

                VStack(spacing: 8) {
                    HStack {
                        Text("❤️ \(lives)")
                        Spacer()
                        Text("\(passedCount)/\(goalPassedCount)")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)

                    ProgressView(value: min(Double(passedCount), Double(goalPassedCount)), total: Double(goalPassedCount))
                        .tint(.green)
                }
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .top)

                Image(petAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: characterSize, height: characterSize)
                    .position(x: playerX, y: groundY - characterSize / 2 + playerY)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

                if !isRunning {
                    GameResultOverlay(
                        title: lives > 0 ? "クリア！" : "ゲームオーバー",
                        tint: lives > 0 ? .green : .red,
                        buttonTitle: "もう一回",
                        onRetry: reset
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard isRunning, playerY >= 0 else { return }
                velocityY = jumpPower
            }
            .onReceive(timer) { _ in
                guard isRunning else { return }

                if Double.random(in: 0...1) < 0.05 {
                    obstacles.append(
                        SideObstacle(
                            x: size.width + 60,
                            width: CGFloat.random(in: 46...64),
                            height: CGFloat.random(in: 44...58),
                            speed: CGFloat.random(in: 4.2...5.8)
                        )
                    )
                }

                velocityY += gravity
                playerY += velocityY
                if playerY > 0 {
                    playerY = 0
                    velocityY = 0
                }

                for idx in obstacles.indices {
                    obstacles[idx].x -= obstacles[idx].speed
                }

                let playerRect = CGRect(
                    x: playerX - characterSize * 0.28,
                    y: groundY - characterSize + playerY + 8,
                    width: characterSize * 0.56,
                    height: characterSize * 0.78
                )

                obstacles.removeAll { obstacle in
                    let obstacleRect = CGRect(
                        x: obstacle.x - obstacle.width / 2,
                        y: groundY - obstacle.height,
                        width: obstacle.width,
                        height: obstacle.height
                    )

                    if obstacleRect.intersects(playerRect) {
                        lives -= 1
                        if lives <= 0 {
                            isRunning = false
                        }
                        return true
                    }

                    if obstacle.x < -80 {
                        passedCount += 1
                        if passedCount >= goalPassedCount {
                            isRunning = false
                        }
                        return true
                    }

                    return false
                }
            }
        }
    }

    private func reset() {
        playerY = 0
        velocityY = 0
        lives = 3
        passedCount = 0
        obstacles = []
        isRunning = true
    }

    private struct SideObstacle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var width: CGFloat
        var height: CGFloat
        var speed: CGFloat
    }
}

private struct RockObstacleView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.72, green: 0.77, blue: 0.84), Color(red: 0.36, green: 0.40, blue: 0.50)], startPoint: .top, endPoint: .bottom))
            Circle().fill(.black.opacity(0.15)).frame(width: 14).offset(x: -10, y: -4)
            Circle().fill(.black.opacity(0.16)).frame(width: 11).offset(x: 12, y: 8)
        }
        .shadow(color: .black.opacity(0.25), radius: 5, y: 4)
    }
}

private struct GuardTapGameView: View {
    let petAssetName: String

    private let goalScore: Int = 20

    @State private var hp: Int = 5
    @State private var score: Int = 0
    @State private var enemies: [Enemy] = []
    @State private var isRunning: Bool = true

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            ZStack {
                GamePanelBackground()

                ForEach(enemies) { enemy in
                    ZStack {
                        Circle()
                            .fill(enemy.color)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .frame(width: 30, height: 30)
                    .position(enemy.position)
                    .onTapGesture {
                        guard isRunning else { return }
                        score += 1
                        enemies.removeAll { $0.id == enemy.id }
                        if score >= goalScore {
                            isRunning = false
                        }
                    }
                }

                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 120)
                    .position(center)

                Image(petAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 98, height: 98)
                    .position(center)

                VStack(spacing: 8) {
                    HStack {
                        Text("🛡️\(hp)")
                        Spacer()
                        Text("\(score)/\(goalScore)")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)

                    ProgressView(value: min(Double(score), Double(goalScore)), total: Double(goalScore))
                        .tint(.cyan)
                }
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .top)

                if !isRunning {
                    GameResultOverlay(
                        title: score >= goalScore ? "クリア！" : "まもりきれなかった…",
                        tint: score >= goalScore ? .green : .red,
                        buttonTitle: "リトライ",
                        onRetry: reset
                    )
                }
            }
            .onReceive(timer) { _ in
                guard isRunning else { return }

                if Double.random(in: 0...1) < 0.06 {
                    enemies.append(Enemy.spawn(in: size))
                }

                for idx in enemies.indices {
                    enemies[idx].moveToward(center: center)
                }

                enemies.removeAll { enemy in
                    if hypot(enemy.position.x - center.x, enemy.position.y - center.y) < 48 {
                        hp -= 1
                        if hp <= 0 {
                            isRunning = false
                        }
                        return true
                    }
                    return false
                }
            }
        }
    }

    private func reset() {
        hp = 5
        score = 0
        enemies = []
        isRunning = true
    }

    private struct Enemy: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var color: Color

        mutating func moveToward(center: CGPoint) {
            position.x += velocity.dx
            position.y += velocity.dy

            let dx = center.x - position.x
            let dy = center.y - position.y
            let dist = max(1, sqrt(dx * dx + dy * dy))
            velocity = CGVector(dx: dx / dist * 2.4, dy: dy / dist * 2.4)
        }

        static func spawn(in size: CGSize) -> Enemy {
            let edge = Int.random(in: 0...3)
            let point: CGPoint
            switch edge {
            case 0: point = CGPoint(x: CGFloat.random(in: 0...size.width), y: -12)
            case 1: point = CGPoint(x: size.width + 12, y: CGFloat.random(in: 0...size.height))
            case 2: point = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 12)
            default: point = CGPoint(x: -12, y: CGFloat.random(in: 0...size.height))
            }

            return Enemy(
                position: point,
                velocity: CGVector(dx: 0, dy: 0),
                color: [.pink, .purple, .cyan, .mint, .orange].randomElement() ?? .pink
            )
        }
    }
}

private struct GameResultOverlay: View {
    let title: String
    let tint: Color
    let buttonTitle: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Button(buttonTitle, action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(tint)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
