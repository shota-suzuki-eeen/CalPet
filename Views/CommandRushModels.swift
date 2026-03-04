import Foundation
import SwiftUI

enum GamePhase: Equatable {
    case ready
    case playing
    case paused
    case cleared
    case gameOver
}

enum CommandKind: CaseIterable, Equatable {
    case tap
    case swipeUp
    case swipeDown
    case swipeLeft
    case swipeRight

    var symbolName: String {
        switch self {
        case .tap: return "hand.tap.fill"
        case .swipeUp: return "arrow.up"
        case .swipeDown: return "arrow.down"
        case .swipeLeft: return "arrow.left"
        case .swipeRight: return "arrow.right"
        }
    }

    var title: String {
        switch self {
        case .tap: return "TAP"
        case .swipeUp: return "UP"
        case .swipeDown: return "DOWN"
        case .swipeLeft: return "LEFT"
        case .swipeRight: return "RIGHT"
        }
    }

    var group: Int {
        switch self {
        case .tap: return 0
        case .swipeUp, .swipeDown: return 1
        case .swipeLeft, .swipeRight: return 2
        }
    }
}

enum InputEvent: Equatable {
    case tap
    case swipe(CommandKind)

    var command: CommandKind {
        switch self {
        case .tap: return .tap
        case .swipe(let kind): return kind
        }
    }
}

struct CurrentCommand: Equatable {
    let kind: CommandKind
    let issuedAt: Date
    let deadlineAt: Date
}

struct DanceTransform: Equatable {
    let offset: CGSize
    let scale: CGFloat
    let rotation: Double
    let opacity: Double

    static let neutral = DanceTransform(offset: .zero, scale: 1.0, rotation: 0, opacity: 1)

    static func forCommand(_ command: CommandKind, amplify: CGFloat = 1) -> DanceTransform {
        switch command {
        case .tap:
            return DanceTransform(offset: CGSize(width: 0, height: -18 * amplify), scale: 1.12, rotation: 2, opacity: 1)
        case .swipeUp:
            return DanceTransform(offset: CGSize(width: 0, height: -32 * amplify), scale: 1.05, rotation: -8, opacity: 1)
        case .swipeDown:
            return DanceTransform(offset: CGSize(width: 0, height: 18 * amplify), scale: 0.9, rotation: 0, opacity: 0.94)
        case .swipeLeft:
            return DanceTransform(offset: CGSize(width: -28 * amplify, height: -4), scale: 1.03, rotation: -10, opacity: 1)
        case .swipeRight:
            return DanceTransform(offset: CGSize(width: 28 * amplify, height: -4), scale: 1.03, rotation: 10, opacity: 1)
        }
    }
}

struct CommandRushResult {
    let score: Int
    let bestScore: Int
    let bestToday: Int
}
