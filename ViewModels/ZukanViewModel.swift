//
//  ZukanViewModel.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/05.
//

import Foundation
import Combine

struct ZukanPetRow: Identifiable {
    let id: String
    let name: String
    let isCurrentPet: Bool
}

// ✅ 図鑑グリッド表示用（12マス固定のため）
struct ZukanPetSlot: Identifiable, Equatable {
    let id: String
    let name: String
    let imageName: String
    let isOwned: Bool
    let isCurrentPet: Bool
}

@MainActor
final class ZukanViewModel: ObservableObject {

    /// ✅ 初期実装予定：12体ぶん固定（図鑑の並び順を固定したいのでここで管理）
    /// - 正本は AppState.initialZukanPetIDs
    var initialPetIDs: [String] { AppState.initialZukanPetIDs }

    /// 既存：所持キャラ一覧（現状UIで使っているので残す）
    func makePetRows(state: AppState) -> [ZukanPetRow] {
        state.ownedPetIDs().map { id in
            .init(
                id: id,
                name: PetMaster.all.first(where: { $0.id == id })?.name ?? id,
                isCurrentPet: id == state.currentPetID
            )
        }
    }

    /// ✅ 追加：図鑑グリッド用（12体ぶんを常に返す）
    /// - 未獲得：CalPet_secret を表示
    /// - 獲得済み：該当キャラのアセット（idと同名想定）を表示
    func makeZukanSlots(state: AppState) -> [ZukanPetSlot] {
        let owned = Set(state.ownedPetIDs())
        let current = state.currentPetID

        return initialPetIDs.map { id in
            let isOwned = owned.contains(id)
            let name = isOwned
                ? (PetMaster.all.first(where: { $0.id == id })?.name ?? id)
                : "？？？"
            let imageName = isOwned ? id : "CalPet_secret"

            return ZukanPetSlot(
                id: id,
                name: name,
                imageName: imageName,
                isOwned: isOwned,
                isCurrentPet: (current == id)
            )
        }
    }
}
