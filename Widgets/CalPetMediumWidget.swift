import WidgetKit
import SwiftUI

struct CalPetMediumEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPetSnapshot
    let motion: MotionFrame

    struct MotionFrame: Equatable {
        let xOffset: CGFloat
        let yOffset: CGFloat
        let scale: CGFloat

        static let idle = MotionFrame(xOffset: 0, yOffset: 0, scale: 1.0)
    }
}

struct CalPetMediumTimelineProvider: TimelineProvider {
    /// WidgetKit の実運用で比較的許容されやすい短間隔として 1 分を採用。
    /// 秒単位更新はシステム制約上ほぼ維持できないため、分単位で「生きている感」を強める。
    private let frameIntervalMinutes = 1
    private let timelineSpanMinutes = 90

    /// 「歩く + たまに止まる + たまに弾む」パターン。
    /// 1分おきにこの配列を循環させる。
    private let motionPattern: [CalPetMediumEntry.MotionFrame] = [
        .init(xOffset: -8, yOffset: -2, scale: 1.00),
        .init(xOffset: -4, yOffset: -4, scale: 1.01),
        .init(xOffset: 0, yOffset: 0, scale: 1.00), // pause
        .init(xOffset: 5, yOffset: -2, scale: 1.00),
        .init(xOffset: 8, yOffset: -1, scale: 1.00),
        .init(xOffset: 3, yOffset: -6, scale: 1.02), // bob
        .init(xOffset: 0, yOffset: 0, scale: 1.00), // pause
        .init(xOffset: -5, yOffset: -1, scale: 1.00),
        .init(xOffset: -2, yOffset: -5, scale: 1.01),
        .init(xOffset: 0, yOffset: 0, scale: 1.00), // pause
    ]

    func placeholder(in context: Context) -> CalPetMediumEntry {
        CalPetMediumEntry(date: Date(), snapshot: .default, motion: .idle)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalPetMediumEntry) -> Void) {
        let snapshot = WidgetPetSnapshotStore.load()
        completion(CalPetMediumEntry(date: Date(), snapshot: snapshot, motion: .idle))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalPetMediumEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetPetSnapshotStore.load()
        var entries: [CalPetMediumEntry] = []

        let frameCount = max(1, timelineSpanMinutes / frameIntervalMinutes)
        for index in 0..<frameCount {
            let offsetMinute = index * frameIntervalMinutes
            let entryDate = Calendar.current.date(byAdding: .minute, value: offsetMinute, to: now) ?? now
            let motion = motionPattern[index % motionPattern.count]
            entries.append(CalPetMediumEntry(date: entryDate, snapshot: snapshot, motion: motion))
        }

        let refresh = Calendar.current.date(byAdding: .minute, value: timelineSpanMinutes, to: now)
            ?? now.addingTimeInterval(TimeInterval(timelineSpanMinutes * 60))
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

struct CalPetMediumWidgetView: View {
    var entry: CalPetMediumTimelineProvider.Entry

    var body: some View {
        ZStack {
            Image("Home_background")
                .resizable()
                .scaledToFill()

            HStack(alignment: .bottom) {
                characterLayer
                    .frame(maxWidth: .infinity, alignment: .leading)

                stepsBadge
            }
            .padding(12)
        }
        .widgetURL(URL(string: "calpet://home"))
    }

    private var characterLayer: some View {
        ZStack(alignment: .bottomLeading) {
            Image(entry.snapshot.displayAssetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 120)
                .scaleEffect(entry.motion.scale)
                .offset(x: entry.motion.xOffset, y: entry.motion.yOffset)

            if entry.snapshot.isBathFlagged {
                Image("yogore")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 110)
                    .scaleEffect(entry.motion.scale)
                    .offset(x: entry.motion.xOffset + 2, y: entry.motion.yOffset)
            }
        }
    }

    private var stepsBadge: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("今日の歩数")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.95))
            Text("\(entry.snapshot.todaySteps)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("steps")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct CalPetMediumWidget: Widget {
    let kind: String = "CalPetMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalPetMediumTimelineProvider()) { entry in
            CalPetMediumWidgetView(entry: entry)
        }
        .configurationDisplayName("CalPet")
        .description("お世話中キャラと今日の歩数を表示します。")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct CalPetMediumWidget_Previews: PreviewProvider {
    static var previews: some View {
        CalPetMediumWidgetView(
            entry: CalPetMediumEntry(
                date: Date(),
                snapshot: WidgetPetSnapshot(
                    currentPetID: "pet_004",
                    displayAssetName: "kakke_wc",
                    isToiletFlagged: true,
                    isBathFlagged: true,
                    todaySteps: 7421,
                    updatedAt: Date()
                ),
                motion: .init(xOffset: -8, yOffset: -2, scale: 1.0)
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
