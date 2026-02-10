//
//  TodayPhotoEntry.swift
//  Cal Pet
//
//  Created by shota suzuki on 2026/02/03.
//

import Foundation
import SwiftData
import UIKit

@Model
final class TodayPhotoEntry {
    // yyyyMMdd
    var dayKey: String
    // 表示用（並び順・ラベル）
    var date: Date
    // documents/memories/ のファイル名（例: 20260203.jpg）
    var fileName: String

    init(dayKey: String, date: Date, fileName: String) {
        self.dayKey = dayKey
        self.date = date
        self.fileName = fileName
    }
}

// MARK: - Storage

enum TodayPhotoStorage {
    static func memoriesDirURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("memories", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func fileURL(fileName: String) throws -> URL {
        try memoriesDirURL().appendingPathComponent(fileName)
    }

    static func loadImage(fileName: String) -> UIImage? {
        do {
            let url = try fileURL(fileName: fileName)
            return UIImage(contentsOfFile: url.path)
        } catch {
            return nil
        }
    }

    static func saveJPEG(_ image: UIImage, fileName: String, quality: CGFloat = 0.9) throws {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw NSError(domain: "TodayPhotoStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "JPEG変換に失敗しました"])
        }
        let url = try fileURL(fileName: fileName)
        try data.write(to: url, options: .atomic)
    }
}
