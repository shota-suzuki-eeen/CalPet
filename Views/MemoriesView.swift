import SwiftUI
import SwiftData
import UIKit

struct MemoriesView: View {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case week = "週"
        case month = "月"
        case year = "年"

        var id: String { rawValue }

        /// できるだけ大きめ（要望）にしつつ、年表示は詰める
        var cellHeight: CGFloat {
            switch self {
            case .week: return 160
            case .month: return 104
            case .year: return 48
            }
        }

        var gridSpacing: CGFloat {
            switch self {
            case .week: return 8
            case .month: return 8
            case .year: return 4
            }
        }

        var cellCornerRadius: CGFloat {
            switch self {
            case .week: return 12
            case .month: return 12
            case .year: return 8
            }
        }
    }

    @Query(sort: \TodayPhotoEntry.date, order: .reverse) private var entries: [TodayPhotoEntry]
    @StateObject private var viewModel = MemoriesViewModel()

    @State private var mode: DisplayMode = .month
    @State private var focusDate: Date = Date()

    private let cal = Calendar.current

    var body: some View {
        let entryMap = makeEntryMap(entries)
        let columns = Array(repeating: GridItem(.flexible(), spacing: mode.gridSpacing), count: 7)

        ZStack {
            Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

            VStack(spacing: 12) {
                modeHeader
                weekdayHeader

                if entries.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        switch mode {
                        case .week:
                            weekGrid(entryMap: entryMap, columns: columns)
                        case .month:
                            monthGrid(entryMap: entryMap, columns: columns)
                        case .year:
                            yearGrid(entryMap: entryMap)
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
        .onChange(of: mode) { _, newMode in
            // 年表示はセル数が多くなるので、切替時に軽くしておく（必要なら削ってOK）
            if newMode == .year {
                viewModel.clearInMemoryCache(keepSelected: true)
            }
        }
    }

    // MARK: - Header

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

    private var weekdayHeader: some View {
        let symbols = weekdaySymbolsStartingFromFirstWeekday()
        return HStack(spacing: mode.gridSpacing) {
            ForEach(symbols, id: \.self) { s in
                Text(s)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
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

    // MARK: - Grids

    private func weekGrid(entryMap: [String: TodayPhotoEntry], columns: [GridItem]) -> some View {
        let days = weekDates(for: focusDate)
        return LazyVGrid(columns: columns, spacing: mode.gridSpacing) {
            ForEach(days, id: \.self) { day in
                dayCell(for: day, entryMap: entryMap)
            }
        }
        .padding(.top, 4)
    }

    private func monthGrid(entryMap: [String: TodayPhotoEntry], columns: [GridItem]) -> some View {
        let slots = monthSlots(for: focusDate)
        return LazyVGrid(columns: columns, spacing: mode.gridSpacing) {
            ForEach(0..<slots.count, id: \.self) { index in
                if let day = slots[index] {
                    dayCell(for: day, entryMap: entryMap)
                } else {
                    RoundedRectangle(cornerRadius: mode.cellCornerRadius)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: mode.cellHeight)
                }
            }
        }
        .padding(.top, 4)
    }

    private func yearGrid(entryMap: [String: TodayPhotoEntry]) -> some View {
        let year = cal.component(.year, from: focusDate)
        let months: [Date] = (1...12).compactMap { month in
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            return cal.date(from: comps)
        }

        let yearColumns = Array(repeating: GridItem(.flexible(), spacing: DisplayMode.year.gridSpacing), count: 7)

        return VStack(spacing: 12) {
            ForEach(months, id: \.self) { monthDate in
                let slots = monthSlots(for: monthDate)

                VStack(alignment: .leading, spacing: 6) {
                    Text(monthTitle(for: monthDate))
                        .font(.subheadline)
                        .bold()

                    LazyVGrid(columns: yearColumns, spacing: DisplayMode.year.gridSpacing) {
                        ForEach(0..<slots.count, id: \.self) { idx in
                            if let day = slots[idx] {
                                yearDayCell(for: day, entryMap: entryMap)
                            } else {
                                RoundedRectangle(cornerRadius: DisplayMode.year.cellCornerRadius)
                                    .fill(Color.white.opacity(0.16))
                                    .frame(height: DisplayMode.year.cellHeight)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Cells（✅ ここが最大の変更点：TodayPhotoStorage直読みを廃止）

    private func dayCell(for date: Date, entryMap: [String: TodayPhotoEntry]) -> some View {
        let key = AppState.makeDayKey(date)
        let entry = entryMap[key]
        let isToday = cal.isDateInToday(date)

        // ✅ まずキャッシュを見る
        let cached = viewModel.image(for: key)

        return VStack(spacing: 2) {
            Text(dayNumber(for: date))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Group {
                if let img = cached {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else if entry != nil {
                    // エントリはあるが未ロード：プレースホルダ（読み込み中）
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.28))
                        .overlay {
                            ProgressView()
                                .tint(.white.opacity(0.9))
                        }
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
        .background(
            RoundedRectangle(cornerRadius: mode.cellCornerRadius)
                .fill(Color.white.opacity(0.22))
        )
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: mode.cellCornerRadius)
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let entry {
                viewModel.select(entry: entry)
            }
        }
        .onAppear {
            // ✅ 表示されたセルだけ遅延ロード
            guard let entry else { return }
            if viewModel.image(for: key) == nil {
                viewModel.loadImageIfNeeded(dayKey: key, fileName: entry.fileName)
            }
        }
    }

    private func yearDayCell(for date: Date, entryMap: [String: TodayPhotoEntry]) -> some View {
        let key = AppState.makeDayKey(date)
        let entry = entryMap[key]
        let isToday = cal.isDateInToday(date)

        let cached = viewModel.image(for: key)

        return ZStack(alignment: .topLeading) {
            if let img = cached {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else if entry != nil {
                Color.white.opacity(0.18)
                    .overlay {
                        ProgressView().tint(.white.opacity(0.9))
                    }
            } else {
                Color.white.opacity(0.18)
            }

            Text(dayNumber(for: date))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.black.opacity(0.25), in: Capsule())
                .padding(6)
        }
        .frame(height: DisplayMode.year.cellHeight)
        .clipShape(RoundedRectangle(cornerRadius: DisplayMode.year.cellCornerRadius))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: DisplayMode.year.cellCornerRadius)
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let entry {
                viewModel.select(entry: entry)
            }
        }
        .onAppear {
            guard let entry else { return }
            if viewModel.image(for: key) == nil {
                viewModel.loadImageIfNeeded(dayKey: key, fileName: entry.fileName)
            }
        }
    }

    // MARK: - Title / Navigation

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

    // MARK: - Date Utils

    private func weekDates(for date: Date) -> [Date] {
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// ✅ 7列×n行に揃える（月末 trailing の nil を追加）
    private func monthSlots(for date: Date) -> [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: date) else { return [] }
        let monthStart = monthInterval.start

        let weekday = cal.component(.weekday, from: monthStart)
        let firstWeekday = cal.firstWeekday
        let leading = (weekday - firstWeekday + 7) % 7

        let days = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        var slots: [Date?] = Array(repeating: nil, count: leading)
        slots.append(contentsOf: (0..<days).compactMap { cal.date(byAdding: .day, value: $0, to: monthStart) })

        let remainder = slots.count % 7
        if remainder != 0 {
            slots.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return slots
    }

    private func monthTitle(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        String(cal.component(.day, from: date))
    }

    private func shortLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d"
        return f.string(from: date)
    }

    private func weekdaySymbolsStartingFromFirstWeekday() -> [String] {
        let symbols = cal.shortStandaloneWeekdaySymbols
        let startIndex = max(0, cal.firstWeekday - 1)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private func makeEntryMap(_ entries: [TodayPhotoEntry]) -> [String: TodayPhotoEntry] {
        entries.reduce(into: [:]) { dict, e in
            if let existing = dict[e.dayKey] {
                if e.date > existing.date { dict[e.dayKey] = e }
            } else {
                dict[e.dayKey] = e
            }
        }
    }
}

// MARK: - Detail

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
