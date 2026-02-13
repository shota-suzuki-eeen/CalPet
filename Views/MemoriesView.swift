import SwiftUI
import SwiftData
import UIKit

struct MemoriesView: View {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case week = "週"
        case month = "月"
        case year = "年"

        var id: String { rawValue }

        var cellHeight: CGFloat {
            switch self {
            case .week: return 160
            case .month: return 104
            case .year: return 48
            }
        }
    }

    @Query(sort: \TodayPhotoEntry.date, order: .reverse) private var entries: [TodayPhotoEntry]
    @StateObject private var viewModel = MemoriesViewModel()

    @State private var mode: DisplayMode = .month
    @State private var focusDate: Date = Date()

    private let cal = Calendar.current

    var body: some View {
        ZStack {
            Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

            VStack(spacing: 12) {
                modeHeader

                if entries.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        switch mode {
                        case .week:
                            weekGrid
                        case .month:
                            monthGrid
                        case .year:
                            yearGrid
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .navigationTitle("思い出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewModel.selectedEntry) { e in
            MemoryDetail(entry: e, image: viewModel.selectedImage, titleText: viewModel.labelText(for: e.date))
        }
    }

    private var modeHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Button { shiftRange(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(titleText)
                    .font(.headline)
                Spacer()
                Button { shiftRange(1) } label: { Image(systemName: "chevron.right") }
            }
            .font(.title3)
            .padding(.horizontal, 2)

            Picker("表示", selection: $mode) {
                ForEach(DisplayMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.top, 8)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("まだ思い出がありません").font(.title3).bold()
            Text("ホームのカメラから撮影できます")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 80)
    }

    private var weekGrid: some View {
        let days = weekDates(for: focusDate)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { day in
                dayCell(for: day, isInCurrentRange: true)
            }
        }
        .padding(.top, 4)
    }

    private var monthGrid: some View {
        let slots = monthSlots(for: focusDate)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(0..<slots.count, id: \.self) { index in
                if let day = slots[index] {
                    dayCell(for: day, isInCurrentRange: true)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: mode.cellHeight)
                }
            }
        }
        .padding(.top, 4)
    }

    private var yearGrid: some View {
        let months = (1...12).compactMap { month -> Date? in
            cal.date(from: cal.dateComponents([.year], from: focusDate).setting(\.month, to: month).setting(\.day, to: 1))
        }

        return VStack(spacing: 12) {
            ForEach(months, id: \.self) { monthDate in
                let slots = monthSlots(for: monthDate)
                VStack(alignment: .leading, spacing: 6) {
                    Text(monthTitle(for: monthDate)).font(.subheadline).bold()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(0..<slots.count, id: \.self) { index in
                            if let day = slots[index] {
                                dayCell(for: day, isInCurrentRange: true)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.16))
                                    .frame(height: mode.cellHeight)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func dayCell(for date: Date, isInCurrentRange: Bool) -> some View {
        let key = AppState.makeDayKey(date)
        let entry = entries.first { $0.dayKey == key }

        return VStack(spacing: 2) {
            Text(dayNumber(for: date))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Group {
                if let entry, let img = TodayPhotoStorage.loadImage(fileName: entry.fileName) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.28))
                        .overlay {
                            Image(systemName: "camera")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: mode.cellHeight - 22)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.22)))
        .contentShape(Rectangle())
        .onTapGesture {
            if let entry {
                viewModel.select(entry: entry)
            }
        }
    }

    private var titleText: String {
        switch mode {
        case .week:
            let days = weekDates(for: focusDate)
            guard let first = days.first, let last = days.last else { return "" }
            return "\(shortLabel(first)) 〜 \(shortLabel(last))"
        case .month:
            return monthTitle(for: focusDate)
        case .year:
            return "\(cal.component(.year, from: focusDate))年"
        }
    }

    private func shiftRange(_ amount: Int) {
        switch mode {
        case .week:
            focusDate = cal.date(byAdding: .weekOfYear, value: amount, to: focusDate) ?? focusDate
        case .month:
            focusDate = cal.date(byAdding: .month, value: amount, to: focusDate) ?? focusDate
        case .year:
            focusDate = cal.date(byAdding: .year, value: amount, to: focusDate) ?? focusDate
        }
    }

    private func weekDates(for date: Date) -> [Date] {
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func monthSlots(for date: Date) -> [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: date) else { return [] }
        let monthStart = monthInterval.start
        let weekday = cal.component(.weekday, from: monthStart)
        let firstWeekday = cal.firstWeekday
        let leading = (weekday - firstWeekday + 7) % 7
        let days = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        var slots: [Date?] = Array(repeating: nil, count: leading)
        slots.append(contentsOf: (0..<days).compactMap { cal.date(byAdding: .day, value: $0, to: monthStart) })
        return slots
    }

    private func monthTitle(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        String(cal.component(.day, from: date))
    }

    private func shortLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

private struct MemoryDetail: View {
    let entry: TodayPhotoEntry
    let image: UIImage?
    let titleText: String

    @Environment(\.dismiss) private var dismiss

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

private extension DateComponents {
    func setting(_ keyPath: WritableKeyPath<DateComponents, Int?>, to value: Int?) -> DateComponents {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}
