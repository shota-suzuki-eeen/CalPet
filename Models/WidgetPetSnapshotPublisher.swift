import Foundation

struct WidgetPetSnapshotPublisher {
    static func makeSnapshot(state: AppState, todaySteps: Int, now: Date = Date()) -> WidgetPetSnapshot {
        let base = PetMaster.assetName(for: state.currentPetID)
        let displayAsset = (state.toiletFlagAt != nil && supportsWcAsset(base)) ? "\(base)_wc" : base

        return WidgetPetSnapshot(
            currentPetID: state.currentPetID,
            displayAssetName: displayAsset,
            isToiletFlagged: state.toiletFlagAt != nil,
            isBathFlagged: state.hasBathFlag,
            todaySteps: max(0, todaySteps),
            updatedAt: now
        )
    }

    private static func supportsWcAsset(_ baseName: String) -> Bool {
        [
            "beat", "biniki", "himei", "kakke", "kepyon", "ninjin",
            "obaoru", "purpor", "sun", "wanigeeta", "wareware"
        ].contains(baseName)
    }
}
