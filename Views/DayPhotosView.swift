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

    // ✅ 追加：保存完了を画面中央に出す
    @State private var centerToastMessage: String?
    @State private var showCenterToast: Bool = false

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
                                            placeTitleText: placeTitleText(for: e),
                                            onDownload: { img in
                                                Task {
                                                    do {
                                                        try await viewModel.saveToPhotos(img)

                                                        // ✅ 仕様：保存完了を画面中央に表示
                                                        showCenterToastNow("保存しました！")

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

                    // ✅ 画面中央トースト（保存完了など）
                    if showCenterToast, let centerToastMessage {
                        CenterToastView(message: centerToastMessage)
                            .transition(.opacity.combined(with: .scale))
                            .zIndex(9999)
                    }
                }
            }

            // ✅ 修正：ナビゲーションバーに “写真情報のタイトル” を出さない
            // （赤丸部分を消すため、title は空にする）
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {
                // ✅ 修正：中央（principal）も空にして、上部に文字が残らないようにする
                ToolbarItem(placement: .principal) {
                    Color.clear.frame(width: 0, height: 0)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }

            // ✅ 既存：ViewModelのtoastMessageを購読（ただし「保存しました！」は中央表示で統一）
            .onChange(of: viewModel.toastMessage) { _, msg in
                guard let msg else { return }

                if msg.contains("保存しました") {
                    showCenterToastNow("保存しました！")
                } else {
                    onToast(msg)
                }
                viewModel.consumeToast()
            }
        }
    }

    // MARK: - Title formatting

    /// ✅ カードタイトル（旧：撮影 HH:mm）→（新：場所 の おもいで）
    private func placeTitleText(for entry: TodayPhotoEntry) -> String {
        let raw = entry.placeName?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let raw, !raw.isEmpty {
            return "\(raw) の おもいで"
        } else {
            // 位置情報が無い/拒否/未取得の場合
            return "おもいで"
        }
    }

    // MARK: - Center toast

    private func showCenterToastNow(_ message: String) {
        centerToastMessage = message
        withAnimation(.easeInOut(duration: 0.15)) {
            showCenterToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.15)) {
                showCenterToast = false
            }
        }
    }
}

private struct PhotoPage: View {
    let entry: TodayPhotoEntry
    let image: UIImage?
    let timeText: String

    // ✅ 追加：場所タイトル
    let placeTitleText: String

    let onDownload: (UIImage) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                Spacer().frame(height: 10)

                // ✅ 仕様変更：タイトルを場所に（バーではなく画面内に表示）
                Text(placeTitleText)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // ✅ 時刻は残したい場合はサブ表示（既存を壊さない）
                Text("撮影 \(timeText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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

// ✅ 画面中央表示用トースト
private struct CenterToastView: View {
    let message: String

    var body: some View {
        VStack {
            Text(message)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.black.opacity(0.82), in: Capsule())
                .shadow(radius: 10)

            // ちょい下に余白（視認性）
            Spacer().frame(height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }
}
