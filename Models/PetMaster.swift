//
//  PetMaster.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/05.
//

import Foundation

// MARK: - Master Item

struct PetMasterItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let personality: String   // MVPは文字列でOK（genki/ottori/tsundere/majime）

    // 将来的に「好物/大好物」倍率を入れる可能性があるので枠だけ用意（現状ロジック未使用）
    // 既存の .init(id:name:personality:) を壊さないためデフォルト値を付与
    let favoriteFoodKind: FoodKind? = nil
    let superFavoriteFoodKind: FoodKind? = nil
}

// MARK: - Care / Friendship (Spec v6)

/// 仕様の固定値（なかよし度・お世話加算など）
/// ※ロジック実装は主に AppState / HomeView 側になる想定だが、値の一元管理としてここに定義
enum FriendshipSpec {
    static let maxPoint: Int = 100

    // なかよしカード
    static let cardThreshold: Int = 100  // 100到達で1枚
    // 余剰分繰り越しあり → 実装側で (point >= 100) を while で回して枚数加算する

    // ご飯（1日最大3回）
    static let foodNormal: Int = 10
    static let foodFavorite: Int = 20
    static let foodSuperFavorite: Int = 30

    // お風呂
    static let bathGain: Int = 15
    static let bathCooldownHours: Int = 8
    static let bathAdReduceHoursPerWatch: Int = 4
    static let bathAdLimitPerDay: Int = 2

    // トイレ
    static let toiletNormal: Int = 10
    static let toiletWithin1h: Int = 20
    static let toiletBonusWindowSeconds: TimeInterval = 60 * 60
}

/// ご飯の種類（倍率仕様は将来）
/// 現時点の仕様では加算値が確定しているので “加算値” を持たせる
enum FoodKind: String, Codable, CaseIterable {
    case normal
    case favorite
    case superFavorite

    var gainPoint: Int {
        switch self {
        case .normal: return FriendshipSpec.foodNormal
        case .favorite: return FriendshipSpec.foodFavorite
        case .superFavorite: return FriendshipSpec.foodSuperFavorite
        }
    }
}

/// ご飯の時間帯（固定）
/// ※「提供可能時間」判定は実装側で Date -> hour を見て判定
enum FoodTimeSlot: String, Codable, CaseIterable {
    case morning
    case noon
    case night
}

// MARK: - Master List

enum PetMaster {
    static let all: [PetMasterItem] = [
        .init(id: "pet_000", name: "はじめの子", personality: "genki"),
        .init(id: "pet_001", name: "もふもふ", personality: "ottori"),
        .init(id: "pet_002", name: "つんつん", personality: "tsundere"),
        .init(id: "pet_003", name: "きっちり", personality: "majime"),
        .init(id: "pet_004", name: "うさっぽ", personality: "genki"),
        .init(id: "pet_005", name: "くまろん", personality: "ottori"),
    ]
}
