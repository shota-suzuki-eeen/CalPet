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
    // Codable 警告回避のため let + 初期値 ではなく var にする
    var favoriteFoodKind: FoodKind? = nil
    var superFavoriteFoodKind: FoodKind? = nil
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

    static let all: [PetMasterItem] = [
        .init(id: "pet_000", name: "パーポー", personality: "genki"),
        .init(id: "pet_001", name: "ビート", personality: "ottori"),
        .init(id: "pet_002", name: "ビニキ", personality: "tsundere"),
        .init(id: "pet_003", name: "ヒメイ", personality: "majime"),
        .init(id: "pet_004", name: "カッケ", personality: "tsundere"),
        .init(id: "pet_005", name: "ケピョン", personality: "tsundere"),
        .init(id: "pet_006", name: "ニンジン", personality: "genki"),
        .init(id: "pet_007", name: "オバオル", personality: "ottori"),
        .init(id: "pet_008", name: "スン", personality: "ottori"),
        .init(id: "pet_009", name: "ワニゲータ", personality: "majime"),
        .init(id: "pet_010", name: "ワレワレ", personality: "genki"),
        .init(id: "pet_011", name: "今後記載予定", personality: "majime"),
    ]

    // ✅ ペットID → アセット名（修正版）
    static func assetName(for petID: String) -> String {
        switch petID {
        case "pet_000": return "purpor"
        case "pet_001": return "beat"
        case "pet_002": return "biniki"
        case "pet_003": return "himei"
        case "pet_004": return "kakke"
        case "pet_005": return "kepyon"
        case "pet_006": return "ninjin"
        case "pet_007": return "obaoru"
        case "pet_008": return "sun"
        case "pet_009": return "wanigeeta"
        case "pet_010": return "wareware"
        default:
            return "purpor" // 安全フォールバック
        }
    }

    // MARK: - ✅ Super Favorite (Master)

    /// ✅ 各キャラの「大好物」名称（マスタ）
    static func superFavoriteFoodName(for petID: String) -> String {
        switch petID {
        case "pet_000": return "おにぎり"
        case "pet_001": return "ラーメン"
        case "pet_002": return "ソフトクリーム"
        case "pet_003": return "ハンバーガー"
        case "pet_004": return "コーラ"
        case "pet_005": return "ヨーグルト"
        case "pet_006": return "サラダ"
        case "pet_007": return "コーヒー"
        case "pet_008": return "お鍋"
        case "pet_009": return "ステーキ"
        case "pet_010": return "ピザ"
        default:
            return "？？？"
        }
    }

    /// ✅ 説明文の本文（大好物行は別で付与する）
    private static func baseDescriptionText(for petID: String) -> String {
        switch petID {
        case "pet_000":
            return "もじゃもじゃ界のムードメーカー。元気いっぱいで、きみの毎日にちょっとした冒険を持ち込んでくれる。"
        case "pet_001":
            return "のんびり屋でマイペース。静かな場所が好きで、たまに急にスイッチが入る。"
        case "pet_002":
            return "ツンとして見えるけど、本当はさみしがり屋。ほめられると機嫌が直るタイプ。"
        case "pet_003":
            return "まじめで几帳面。決めたことは最後までやり抜く。小さな達成感がだいすき。"
        case "pet_004":
            return "強がりだけど情に厚い。仲間のためならつい頑張りすぎちゃう。"
        case "pet_005":
            return "ツンデレ代表。距離感は独特だけど、慣れるとすごく頼ってくる。"
        case "pet_006":
            return "いつも元気で前向き。思い立ったら即行動、みんなを巻き込んでいく。"
        case "pet_007":
            return "落ち着いた雰囲気の聞き上手。ゆっくり過ごす時間を大切にしている。"
        case "pet_008":
            return "ぽわっとした癒し系。日だまりみたいに、そばにいるだけで安心できる。"
        case "pet_009":
            return "責任感が強く、面倒見がいい。困っていると放っておけない。"
        case "pet_010":
            return "にぎやか担当。楽しいことに目がなく、笑いがあるところに現れる。"
        default:
            return "今後記載予定"
        }
    }

    // MARK: - Description API

    /// ✅ 既存互換：stateを渡さない場合は常に「？？？」表示（初期状態と同じ）
    static func description(for petID: String) -> String {
        let base = baseDescriptionText(for: petID)
        return base + "\n\n【大好物】？？？"
    }

    /// ✅ 追加：図鑑の表示用（判明済みなら大好物名を表示）
    static func description(for petID: String, state: AppState) -> String {
        let base = baseDescriptionText(for: petID)

        let revealed = state.isSuperFavoriteRevealed(petID: petID)
        let foodText = revealed ? superFavoriteFoodName(for: petID) : "？？？"

        return base + "\n\n【大好物】" + foodText
    }
}
