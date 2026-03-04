import Foundation
import SwiftUI

struct MiniGameItem: Identifiable, Hashable {
    enum Availability {
        case available
        case comingSoon
    }

    let id: String
    let title: String
    let description: String
    let symbolName: String
    let availability: Availability

    static let commandRush = MiniGameItem(
        id: "command_rush",
        title: "コマンドラッシュ",
        description: "タップ＆スワイプでペットとダンス",
        symbolName: "figure.dance",
        availability: .available
    )

    static let comingSoonItems: [MiniGameItem] = [
        MiniGameItem(
            id: "coming_1",
            title: "ビートジャンプ",
            description: "Coming Soon",
            symbolName: "music.note",
            availability: .comingSoon
        ),
        MiniGameItem(
            id: "coming_2",
            title: "リズムキャッチ",
            description: "Coming Soon",
            symbolName: "sparkles",
            availability: .comingSoon
        )
    ]
}
