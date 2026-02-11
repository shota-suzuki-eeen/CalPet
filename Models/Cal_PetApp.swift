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

    // ✅ アプリ全体でBGMを1つだけ管理
    @StateObject private var bgmManager = BGMManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                // ✅ 必要なら今後どのViewからでも操作できるようにしておく
                .environmentObject(bgmManager)
                // ✅ アプリ起動時にBGM開始（多重起動しないようBGMManager側でガード）
                .onAppear {
                    bgmManager.startIfNeeded()
                }
        }
        // ✅ TodayPhotoEntry を追加
        .modelContainer(for: [AppState.self, TodayPhotoEntry.self])
    }
}
