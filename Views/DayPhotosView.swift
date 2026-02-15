//
//  DayPhotosView.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/15.
//

import SwiftUI
import SwiftData
import UIKit

struct DayPhotosView: View {
    let dayKey: String
    let initialFileName: String?   // ✅ これで開始インデックスを決める
    let titleText: String

    @ObservedObject var viewModel: MemoriesViewModel
    let onToast: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @Query private var dayEntries: [TodayPhotoEntry]

    init(
        dayKey: String,
        initialFileName: String?,
        titleText: String,
        viewModel: MemoriesViewModel,
        onToast: @escaping (String) -> Void
    ) {
        self.dayKey = dayKey
        self.initialFileName = initialFileName
        self.titleText = titleText
        self.viewModel = viewModel
        self.onToast = onToast

        let predicate = #Predicate<TodayPhotoEntry> { $0.dayKey == dayKey }
        _dayEntries = Query(filter: predicate, sort: [SortDescriptor(\.date, order: .reverse)])
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

                    if dayEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("この日の写真がありません")
                                .font(.title3).bold()
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(.vertical) {
                                LazyVStack(spacing: 0) {
                                    ForEach(dayEntries) { e in
                                        PhotoPage(
                                            entry: e,
                                            image: viewModel.image(forFileName: e.fileName),
                                            timeText: viewModel.timeText(for: e.date),
                                            onDownload: { img in
                                                Task {
                                                    do {
                                                        try await viewModel.saveToPhotos(img)
                                                        onToast("保存完了しました") // ✅ 要望：成功メッセージ
                                                    } catch {
                                                        onToast(error.localizedDescription)
                                                    }
                                                }
                                            }
                                        )
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .scrollTargetLayout()
                                        .id(e.persistentModelID) // ✅ scrollTo 用（安定）
                                        .onAppear {
                                            if viewModel.image(forFileName: e.fileName) == nil {
                                                viewModel.loadImageIfNeeded(fileName: e.fileName)
                                            }
                                        }
                                    }
                                }
                            }
                            .scrollIndicators(.hidden)
                            .scrollTargetBehavior(.paging)
                            .onAppear {
                                // ✅ 初回だけ “タップ位置” に合わせて開く
                                if let initialFileName,
                                   let target = dayEntries.first(where: { $0.fileName == initialFileName }) {
                                    DispatchQueue.main.async {
                                        proxy.scrollTo(target.persistentModelID, anchor: .top)
                                    }
                                }
                            }
                        }
                    }
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

private struct PhotoPage: View {
    let entry: TodayPhotoEntry
    let image: UIImage?
    let timeText: String
    let onDownload: (UIImage) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                Spacer().frame(height: 10)

                Text("撮影 \(timeText)")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 12)
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("読み込み中…")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                Spacer()
            }

            if let image {
                Button {
                    onDownload(image)
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.black.opacity(0.78), in: Circle())
                        .shadow(radius: 8)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
}
