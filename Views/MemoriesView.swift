import SwiftUI
import SwiftData
import UIKit

struct MemoriesView: View {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case day = "day"
        case week = "week"
        case month = "month"

        var id: String { rawValue }

        var cellHeight: CGFloat {
            switch self {
            case .week: return 160
            case .month: return 104
            case .day: return 0
            }
        }

        var gridSpacing: CGFloat {
            switch self {
            case .week: return 8
            case .month: return 8
            case .day: return 0
            }
        }

        var cellCornerRadius: CGFloat {
            switch self {
            case .week: return 12
            case .month: return 12
            case .day: return 0
            }
        }
    }

    @Query(sort: \TodayPhotoEntry.date, order: .reverse) private var entries: [TodayPhotoEntry]
    @StateObject private var viewModel = MemoriesViewModel()

    // ✅ day を一番左＆デフォルト
    @State private var mode: DisplayMode = .day
    @State private var focusDate: Date = Date()

    // ✅ シート（同日写真ビュー）
    @State private var sheetItem: DayPhotosSheetItem?

    // トースト
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    private let cal = Calendar.current

    var body: some View {
        let entryMap = makeEntryMapLatestPerDay(entries)
        let columns = Array(repeating: GridItem(.flexible(), spacing: mode.gridSpacing), count: 7)

        ZStack {
            Color(red: 0.35, green: 0.86, blue: 0.88).ignoresSafeArea()

            VStack(spacing: 12) {
                modeHeader

                if mode != .day {
                    weekdayHeader
                }

                if entries.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        switch mode {
                        case .day:
                            dayList(entries: entries)

                        case .week:
                            weekGrid(entryMap: entryMap, columns: columns)

                        case .month:
                            monthGrid(entryMap: entryMap, columns: columns)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if showToast, let toastMessage {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 8)
                        .padding(.bottom, 18)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("思い出")
        .navigationBarTitleDisplayMode(.inline)

        // ✅ DayPhotosView は “別ファイル” のものを開く（重複定義しない）
        .sheet(item: $sheetItem) { item in
            DayPhotosView(
                dayKey: item.dayKey,
                initialFileName: item.initialFileName,
                titleText: item.titleText,
                viewModel: viewModel,
                onToast: toast
            )
        }

        .onChange(of: mode) { _, newMode in
            if newMode == .day {
                viewModel.clearInMemoryCache(keepSelectedDay: true)
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

    // ✅ day：縦に写真が並ぶ（撮影時間の降順）
    private func dayList(entries: [TodayPhotoEntry]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(entries) { e in
                DayRow(entry: e, thumb: viewModel.image(forFileName: e.fileName))
                    .onTapGesture {
                        // ✅ ここが要望：タップした写真の位置から開く
                        sheetItem = DayPhotosSheetItem(
                            dayKey: e.dayKey,
                            initialFileName: e.fileName,
                            titleText: dayTitleText(e.dayKey)
                        )
                    }
                    .onAppear {
                        if viewModel.image(forFileName: e.fileName) == nil {
                            viewModel.loadImageIfNeeded(fileName: e.fileName)
                        }
                    }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Cells（week/month）

    private func dayCell(for date: Date, entryMap: [String: TodayPhotoEntry]) -> some View {
        let key = AppState.makeDayKey(date)
        let entry = entryMap[key]
        let isToday = cal.isDateInToday(date)

        let cached = viewModel.thumbnailImage(for: key)

        return VStack(spacing: 2) {
            Text(dayNumber(for: date))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Group {
                if let img = cached {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else if let entry {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.28))
                        .overlay { ProgressView().tint(.white.opacity(0.9)) }
                        .onAppear {
                            if viewModel.thumbnailImage(for: key) == nil {
                                viewModel.loadThumbnailIfNeeded(dayKey: key, fileName: entry.fileName)
                            }
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
            guard entry != nil else { return }
            // ✅ week/month は「その日の最新」から開く（initialFileName=nil）
            sheetItem = DayPhotosSheetItem(
                dayKey: key,
                initialFileName: nil,
                titleText: dayTitleText(key)
            )
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
        case .day:
            return "すべて"
        }
    }

    private func shiftRange(_ amount: Int) {
        switch mode {
        case .week:
            focusDate = cal.date(byAdding: .weekOfYear, value: amount, to: focusDate) ?? focusDate
        case .month:
            focusDate = cal.date(byAdding: .month, value: amount, to: focusDate) ?? focusDate
        case .day:
            break
        }
    }

    // MARK: - Date Utils

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

    private func makeEntryMapLatestPerDay(_ entries: [TodayPhotoEntry]) -> [String: TodayPhotoEntry] {
        entries.reduce(into: [:]) { dict, e in
            if let existing = dict[e.dayKey] {
                if e.date > existing.date { dict[e.dayKey] = e }
            } else {
                dict[e.dayKey] = e
            }
        }
    }

    private func dayTitleText(_ dayKey: String) -> String {
        if dayKey.count == 8 {
            let y = dayKey.prefix(4)
            let m = dayKey.dropFirst(4).prefix(2)
            let d = dayKey.suffix(2)
            return "\(y)/\(m)/\(d)"
        }
        return dayKey
    }

    // MARK: - Toast
    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) { showToast = false }
        }
    }
}

// MARK: - Day Row

private struct DayRow: View {
    let entry: TodayPhotoEntry
    let thumb: UIImage?

    private let bg = Color.white.opacity(0.22)

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.18)
                        .overlay { ProgressView().tint(.white.opacity(0.9)) }
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(label(entry.date))
                    .font(.headline)
                Text(sub(entry))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(bg, in: RoundedRectangle(cornerRadius: 16))
    }

    private func label(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }

    private func sub(_ entry: TodayPhotoEntry) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return "撮影 \(f.string(from: entry.date))"
    }
}

// MARK: - Sheet Item
private struct DayPhotosSheetItem: Identifiable {
    let dayKey: String
    let initialFileName: String?
    let titleText: String
    var id: String { dayKey + "|" + (initialFileName ?? "latest") }
}
