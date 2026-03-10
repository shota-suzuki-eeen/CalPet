import Foundation

struct WidgetPetSnapshot: Codable {
    let currentPetID: String
    let displayAssetName: String
    let isToiletFlagged: Bool
    let isBathFlagged: Bool
    let todaySteps: Int
    let updatedAt: Date

    static let `default` = WidgetPetSnapshot(
        currentPetID: "pet_000",
        displayAssetName: "purpor",
        isToiletFlagged: false,
        isBathFlagged: false,
        todaySteps: 0,
        updatedAt: Date()
    )
}

enum WidgetSharedConfig {
    // NOTE: Xcode capability の App Groups でも同じ ID を設定してください。
    static let appGroupID = "group.xxx.calpet"
    static let snapshotKey = "widget.pet.snapshot"
}

enum WidgetPetSnapshotStore {
    static func save(_ snapshot: WidgetPetSnapshot) {
        guard let defaults = UserDefaults(suiteName: WidgetSharedConfig.appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: WidgetSharedConfig.snapshotKey)
    }

    static func load() -> WidgetPetSnapshot {
        guard let defaults = UserDefaults(suiteName: WidgetSharedConfig.appGroupID),
              let data = defaults.data(forKey: WidgetSharedConfig.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetPetSnapshot.self, from: data) else {
            return .default
        }
        return snapshot
    }
}
