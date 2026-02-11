import Foundation
import Combine

struct ZukanPetRow: Identifiable {
    let id: String
    let name: String
    let isCurrentPet: Bool
}

@MainActor
final class ZukanViewModel: ObservableObject {
    func makePetRows(state: AppState) -> [ZukanPetRow] {
        state.ownedPetIDs().map { id in
            .init(
                id: id,
                name: PetMaster.all.first(where: { $0.id == id })?.name ?? id,
                isCurrentPet: id == state.currentPetID
            )
        }
    }
}
