import Foundation
import Combine
import UIKit

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published var selectedEntry: TodayPhotoEntry?
    @Published var selectedImage: UIImage?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = .current
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    func select(entry: TodayPhotoEntry) {
        selectedEntry = entry
        selectedImage = TodayPhotoStorage.loadImage(fileName: entry.fileName)
    }

    func labelText(for date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
