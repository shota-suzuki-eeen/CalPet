import SwiftUI

struct MiniGamesHubView: View {
    @Environment(\.dismiss) private var dismiss

    let state: AppState

    @State private var selectedGame: MiniGameItem?

    private let items: [MiniGameItem] = [MiniGameItem.commandRush] + MiniGameItem.comingSoonItems
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.purple.opacity(0.8), Color.blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            gameCard(item)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("ミニゲーム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .fullScreenCover(item: $selectedGame) { game in
            if game.id == MiniGameItem.commandRush.id {
                CommandRushView(state: state)
            }
        }
    }

    @ViewBuilder
    private func gameCard(_ item: MiniGameItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: item.symbolName)
                .font(.system(size: 30, weight: .bold))
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(item.title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(item.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(item.availability == .available ? "遊ぶ" : "Coming Soon") {
                if item.availability == .available {
                    selectedGame = item
                }
            }
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(item.availability == .available ? Color.white : Color.white.opacity(0.2))
            .foregroundStyle(item.availability == .available ? .black : .white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(item.availability != .available)
        }
        .padding(14)
        .frame(height: 180)
        .background(.ultraThinMaterial.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}
