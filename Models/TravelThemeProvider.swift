import SwiftUI

struct TravelTheme {
    let gradient: LinearGradient
    let accent: Color
    let label: String
}

struct TravelThemeProvider {
    func theme(for date: Date = Date()) -> TravelTheme {
        let hour = Calendar.current.component(.hour, from: date)
        let season = seasonLabel(for: date)

        switch hour {
        case 5..<10:
            return .init(gradient: .init(colors: [.mint.opacity(0.7), .blue.opacity(0.45)], startPoint: .top, endPoint: .bottom), accent: .yellow, label: "朝 • \(season)")
        case 10..<16:
            return .init(gradient: .init(colors: [.cyan.opacity(0.85), .green.opacity(0.35)], startPoint: .top, endPoint: .bottom), accent: .white, label: "昼 • \(season)")
        case 16..<19:
            return .init(gradient: .init(colors: [.orange.opacity(0.8), .purple.opacity(0.45)], startPoint: .top, endPoint: .bottom), accent: .white, label: "夕 • \(season)")
        default:
            return .init(gradient: .init(colors: [.indigo.opacity(0.95), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom), accent: .yellow, label: "夜 • \(season)")
        }
    }

    private func seasonLabel(for date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3...5: return "春"
        case 6...8: return "夏"
        case 9...11: return "秋"
        default: return "冬"
        }
    }
}
