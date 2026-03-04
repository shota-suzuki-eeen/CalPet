import Foundation
import SwiftUI

enum CommandRushGamePhase: Equatable {
    case ready
    case playing
    case paused
    case cleared
    case gameOver
}

enum CommandKind: String, CaseIterable, Codable, Hashable {
    case tap
    case longPress
    case swipeUp
    case swipeDown
    case swipeLeft
    case swipeRight
    case pinchIn
    case pinchOut
    case shake

    var symbolName: String {
        switch self {
        case .tap: return "hand.tap.fill"
        case .longPress: return "hand.point.up.left.fill"
        case .swipeUp: return "arrow.up"
        case .swipeDown: return "arrow.down"
        case .swipeLeft: return "arrow.left"
        case .swipeRight: return "arrow.right"
        case .pinchIn: return "arrow.down.right.and.arrow.up.left"
        case .pinchOut: return "arrow.up.left.and.arrow.down.right"
        case .shake: return "iphone.gen3.radiowaves.left.and.right"
        }
    }

    var accentColor: Color {
        switch self {
        case .tap: return .cyan
        case .longPress: return .blue
        case .swipeUp, .swipeDown, .swipeLeft, .swipeRight: return .mint
        case .pinchIn, .pinchOut: return .purple
        case .shake: return .orange
        }
    }
}

enum InputEvent: Equatable {
    case tap
    case longPress
    case swipeUp
    case swipeDown
    case swipeLeft
    case swipeRight
    case pinchIn
    case pinchOut
    case shake

    var asCommand: CommandKind {
        switch self {
        case .tap: return .tap
        case .longPress: return .longPress
        case .swipeUp: return .swipeUp
        case .swipeDown: return .swipeDown
        case .swipeLeft: return .swipeLeft
        case .swipeRight: return .swipeRight
        case .pinchIn: return .pinchIn
        case .pinchOut: return .pinchOut
        case .shake: return .shake
        }
    }
}

struct CurrentCommand: Equatable {
    let id: UUID
    let kind: CommandKind
    let issuedAt: Date
    let deadlineAt: Date
}
