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

enum FriendshipSpec {
    static let maxPoint: Int = 100

    static let cardThreshold: Int = 100

    static let foodNormal: Int = 10
    static let foodFavorite: Int = 20
    static let foodSuperFavorite: Int = 30

    static let bathGain: Int = 15
    static let bathCooldownHours: Int = 8
    static let bathAdReduceHoursPerWatch: Int = 4
    static let bathAdLimitPerDay: Int = 2

    static let toiletNormal: Int = 10
    static let toiletWithin1h: Int = 20
    static let toiletBonusWindowSeconds: TimeInterval = 60 * 60
}

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

enum FoodTimeSlot: String, Codable, CaseIterable {
    case morning
    case noon
    case night
}

// MARK: - Master List

enum PetMaster {
    // ✅ 初期実装予定：12体（pet_000 ... pet_011）
    static let all: [PetMasterItem] = [
        .init(id: "pet_000", name: "パーポー", personality: "genki"),
        .init(id: "pet_001", name: "今後記載予定", personality: "ottori"),
        .init(id: "pet_002", name: "今後記載予定", personality: "tsundere"),
        .init(id: "pet_003", name: "今後記載予定", personality: "majime"),
        .init(id: "pet_004", name: "今後記載予定", personality: "genki"),
        .init(id: "pet_005", name: "今後記載予定", personality: "ottori"),
        .init(id: "pet_006", name: "今後記載予定", personality: "tsundere"),
        .init(id: "pet_007", name: "今後記載予定", personality: "majime"),
        .init(id: "pet_008", name: "今後記載予定", personality: "genki"),
        .init(id: "pet_009", name: "今後記載予定", personality: "ottori"),
        .init(id: "pet_010", name: "今後記載予定", personality: "tsundere"),
        .init(id: "pet_011", name: "今後記載予定", personality: "majime"),
    ]

    // ✅ ペットID → アセット名
    static func assetName(for petID: String) -> String {
        switch petID {
        case "pet_000":
            return "purpor"
        default:
            return petID
        }
    }

    // ✅ 追加：ペットID → 説明文
    // まずは固定文でOK（将来は PetMasterItem に description を追加しても良い）
    static func description(for petID: String) -> String {
        switch petID {
        case "pet_000":
            return "もじゃもじゃ界のムードメーカー。元気いっぱいで、きみの毎日にちょっとした冒険を持ち込んでくれる。"
        case "pet_001":
            return "今後記載予定"
        case "pet_002":
            return "今後記載予定"
        case "pet_003":
            return "今後記載予定"
        case "pet_004":
            return "今後記載予定"
        case "pet_005":
            return "今後記載予定"
        case "pet_006":
            return "今後記載予定"
        case "pet_007":
            return "今後記載予定"
        case "pet_008":
            return "今後記載予定"
        case "pet_009":
            return "今後記載予定"
        case "pet_010":
            return "今後記載予定"
        case "pet_011":
            return "今後記載予定"
        default:
            return "今後記載予定"
        }
    }
}
