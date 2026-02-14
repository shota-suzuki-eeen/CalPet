import Foundation
import Combine
import UIKit

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published var selectedEntry: TodayPhotoEntry?
    @Published var selectedImage: UIImage?

    /// グリッド用：dayKey -> UIImage（サムネ/原寸どちらでも）
    @Published private(set) var imageCache: [String: UIImage] = [:]

    /// 読み込み中の二重起動防止
    private var loadingKeys: Set<String> = []

    /// メモリキャッシュ（自動で破棄されやすい）
    private let nsCache = NSCache<NSString, UIImage>()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = .current
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    // MARK: - Public

    func select(entry: TodayPhotoEntry) {
        selectedEntry = entry

        // すでにキャッシュがあれば即表示
        if let cached = cachedImage(for: entry.dayKey) {
            selectedImage = cached
            return
        }

        // 無ければ読み込み
        loadImageIfNeeded(dayKey: entry.dayKey, fileName: entry.fileName, alsoSetSelected: true)
    }

    func labelText(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    /// グリッド側から「この日の画像が必要」と要求されたときに呼ぶ
    func loadImageIfNeeded(dayKey: String, fileName: String) {
        loadImageIfNeeded(dayKey: dayKey, fileName: fileName, alsoSetSelected: false)
    }

    /// グリッド側が使う：キャッシュにあれば返す
    func image(for dayKey: String) -> UIImage? {
        cachedImage(for: dayKey)
    }

    /// メモリを節約したい時に呼べる（例：年表示に切替時など）
    func clearInMemoryCache(keepSelected: Bool = true) {
        let keepKey = keepSelected ? selectedEntry?.dayKey : nil

        imageCache.removeAll(keepingCapacity: false)
        nsCache.removeAllObjects()
        loadingKeys.removeAll()

        if let keepKey, let img = selectedImage {
            imageCache[keepKey] = img
            nsCache.setObject(img, forKey: keepKey as NSString)
        }
    }

    // MARK: - Private

    private func cachedImage(for dayKey: String) -> UIImage? {
        if let img = imageCache[dayKey] { return img }
        if let img = nsCache.object(forKey: dayKey as NSString) {
            imageCache[dayKey] = img
            return img
        }
        return nil
    }

    private func loadImageIfNeeded(dayKey: String, fileName: String, alsoSetSelected: Bool) {
        // すでにあるなら終了
        if let img = cachedImage(for: dayKey) {
            if alsoSetSelected { selectedImage = img }
            return
        }

        // 読み込み中なら終了
        if loadingKeys.contains(dayKey) { return }
        loadingKeys.insert(dayKey)

        // ディスク読み込みはバックグラウンドへ
        Task.detached(priority: .utility) {
            let img = TodayPhotoStorage.loadImage(fileName: fileName)

            await MainActor.run {
                self.loadingKeys.remove(dayKey)

                guard let img else { return }

                self.imageCache[dayKey] = img
                self.nsCache.setObject(img, forKey: dayKey as NSString)

                if alsoSetSelected, self.selectedEntry?.dayKey == dayKey {
                    self.selectedImage = img
                }
            }
        }
    }
}
