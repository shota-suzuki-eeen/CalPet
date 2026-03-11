//
//  WidgetPetSnapshot.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import Foundation

struct WidgetPetSnapshot: Equatable {
    let toiletFlag: Bool
    let bathFlag: Bool
    let currentPetID: String
    let todaySteps: Int

    static let `default` = WidgetPetSnapshot(
        toiletFlag: false,
        bathFlag: false,
        currentPetID: "pet_000",
        todaySteps: 0
    )

    var isToiletFlagged: Bool { toiletFlag }
    var isBathFlagged: Bool { bathFlag }

    var displayAssetName: String {
        let base = WidgetPetAssetMap.assetName(for: currentPetID)
        if toiletFlag, WidgetPetAssetMap.hasToiletVariant(baseAssetName: base) {
            return "\(base)_wc"
        }
        return base
    }
}

enum WidgetPetAssetMap {
    static func assetName(for petID: String) -> String {
        switch petID.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "pet_000": return "purpor"
        case "pet_001": return "obaoru"
        case "pet_002": return "ninjin"
        case "pet_003": return "kakke"
        case "pet_004": return "beat"
        case "pet_005": return "biniki"
        case "pet_006": return "himei"
        case "pet_007": return "kepyon"
        case "pet_008": return "sun"
        case "pet_009": return "wanigeeta"
        case "pet_010": return "wareware"
        case "pet_011": return "purpor"   // 未実装時の保険
        default: return "purpor"
        }
    }

    static func hasToiletVariant(baseAssetName: String) -> Bool {
        [
            "beat",
            "biniki",
            "himei",
            "kakke",
            "kepyon",
            "ninjin",
            "obaoru",
            "purpor",
            "sun",
            "wanigeeta",
            "wareware"
        ].contains(baseAssetName)
    }
}
