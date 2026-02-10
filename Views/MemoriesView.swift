//
//  MemoriesView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import SwiftUI
import SwiftData
import UIKit

struct MemoriesView: View {
    @Query(sort: \TodayPhotoEntry.date, order: .reverse) private var entries: [TodayPhotoEntry]
    @State private var selected: TodayPhotoEntry?
    @State private var selectedImage: UIImage?

    var body: some View {
        ZStack {
            // ✅ Home/Shopと同系色（不要なら Color.clear にしてOK）
            Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

            Group {
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("まだ思い出がありません").font(.title3).bold()
                        Text("ホームの「今日の一枚」から追加できます")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(entries) { e in
                                MemoryTile(entry: e)
                                    .onTapGesture {
                                        selected = e
                                        selectedImage = TodayPhotoStorage.loadImage(fileName: e.fileName)
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("思い出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { e in
            MemoryDetail(entry: e, image: selectedImage)
        }
    }
}

private struct MemoryTile: View {
    let entry: TodayPhotoEntry

    private var label: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = .current
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: entry.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let img = TodayPhotoStorage.loadImage(fileName: entry.fileName) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.thinMaterial)
                        .frame(height: 140)
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
            }

            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MemoryDetail: View {
    let entry: TodayPhotoEntry
    let image: UIImage?

    @Environment(\.dismiss) private var dismiss

    private var titleText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = .current
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: entry.date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

                VStack {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    } else {
                        Text("画像を読み込めませんでした")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    Spacer()
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
