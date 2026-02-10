//
//  Cal_PetApp.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import SwiftUI
import SwiftData

@main
struct Cal_PetApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // ✅ TodayPhotoEntry を追加
        .modelContainer(for: [AppState.self, TodayPhotoEntry.self])
    }
}
