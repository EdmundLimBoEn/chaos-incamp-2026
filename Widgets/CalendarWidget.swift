import SwiftUI
import WidgetKit

struct CalendarEntry: TimelineEntry {
    let date: Date
    let events: [CalendarEvent]
    var needsSetup = false
}

struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now, events: [CalendarEvent(title: "Design sprint", start: .now.addingTimeInterval(1800), end: .now.addingTimeInterval(5400))])
    }
    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        let events = WidgetEventSnapshot.read()
        completion(CalendarEntry(date: .now, events: events ?? [], needsSetup: events == nil))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let now = Date()
        let events = WidgetEventSnapshot.read()
        let horizon = now.addingTimeInterval(6 * 3600)
        let boundaries = (events ?? []).flatMap { [$0.start, $0.end] }.filter { $0 > now && $0 < horizon }
        let dates = [now] + Array(Array(Set(boundaries)).sorted().prefix(40))
        let entries = dates.map { date in
            CalendarEntry(date: date, events: (events ?? []).filter { $0.end > date }.sorted { $0.start < $1.start }, needsSetup: events == nil)
        }
        completion(Timeline(entries: entries, policy: .after(horizon)))
    }
}

struct CalendarWidgetView: View {
    let entry: CalendarEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide))).font(.caption.bold()).foregroundStyle(.red)
                    Text(entry.date.formatted(.dateTime.day().month(.abbreviated))).font(.title2.bold())
                }
                Spacer()
                Image(systemName: "calendar").foregroundStyle(.red)
            }
            if entry.events.isEmpty {
                Spacer(minLength: 0)
                Text(entry.needsSetup ? "Open the app to load your calendar." : "Nothing coming up.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(entry.events.prefix(family == .systemSmall ? 1 : 3)) { event in
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 2).fill(event.color.tint).frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(.caption.bold()).lineLimit(1)
                            Text(timeLabel(event)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }.fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.background, for: .widget)
        .privacySensitive()
    }

    private func timeLabel(_ event: CalendarEvent) -> String {
        if event.isAllDay { return event.start.formatted(.dateTime.month(.abbreviated).day()) + " · All day" }
        if event.start <= entry.date { return "Now · until " + event.end.formatted(date: .omitted, time: .shortened) }
        return event.start.formatted(date: .abbreviated, time: .shortened)
    }
}

@main
struct UpcomingCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetEventSnapshot.kind, provider: CalendarProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("sstincky calander")
        .description("Your next events, available offline.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
