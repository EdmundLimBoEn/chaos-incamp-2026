import SwiftUI

struct DayTimeline: View {
    let events: [CalendarEvent]
    let date: Date
    let edit: (CalendarEvent) -> Void
    @ScaledMetric(relativeTo: .body) private var hourHeight: CGFloat = 76
    @ScaledMetric(relativeTo: .caption) private var gutter: CGFloat = 56

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if !allDayEvents.isEmpty { allDaySection }
                    hourLines
                        .overlay(alignment: .topLeading) {
                            GeometryReader { geometry in
                                ZStack(alignment: .topLeading) {
                                    ForEach(placements) { item in
                                        let width = max(1, (geometry.size.width - gutter) / CGFloat(item.columns))
                                        let height = max(26, CGFloat(item.end - item.start) / 60 * hourHeight - 3)
                                        eventCard(item, height: height)
                                            .frame(width: max(1, width - 5), height: height)
                                            .offset(x: gutter + CGFloat(item.column) * width, y: CGFloat(item.start) / 60 * hourHeight)
                                    }
                                    if Calendar.current.isDateInToday(date) { currentTimeLine }
                                }
                            }
                        }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .task(id: Calendar.current.startOfDay(for: date)) {
                await Task.yield()
                guard !Task.isCancelled else { return }
                proxy.scrollTo(initialHour, anchor: .top)
            }
        }
    }

    private var allDaySection: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("All day")
                .font(.caption.weight(.medium))
                .foregroundStyle(LaunchAppearance.palette.secondary)
                .frame(width: gutter - 8, alignment: .trailing)
                .padding(.top, 14)
            VStack(spacing: 6) {
                ForEach(allDayEvents) { event in
                    Button { edit(event) } label: {
                        HStack(spacing: 9) {
                            Capsule().fill(event.color.tint).frame(width: 3, height: 22)
                            Text(event.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                                .foregroundStyle(LaunchAppearance.palette.secondary)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 46)
                        .foregroundStyle(LaunchAppearance.palette.foreground)
                        .background(event.color.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(event.title + ", all day")
                }
            }
        }
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(LaunchAppearance.palette.secondary)
                        .frame(width: gutter - 8, alignment: .trailing)
                        .offset(y: -7)
                    Rectangle()
                        .fill(LaunchAppearance.palette.foreground.opacity(0.1))
                        .frame(height: 0.5)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
    }

    private func eventCard(_ item: TimelinePlacement, height: CGFloat) -> some View {
        Button { edit(item.event) } label: {
            HStack(alignment: .top, spacing: 7) {
                Capsule().fill(item.event.color.tint).frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(item.event.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(height < 52 ? 1 : 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if item.conflict {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(LaunchAppearance.palette.danger)
                                .accessibilityHidden(true)
                        }
                    }
                    if height >= 60 {
                        Text(item.event.start.formatted(date: .omitted, time: .shortened) + " – " + item.event.end.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(LaunchAppearance.palette.secondary)
                            .lineLimit(1)
                    }
                    if height >= 100 && !item.event.location.isEmpty {
                        Label(item.event.location, systemImage: "location")
                            .font(.caption2)
                            .foregroundStyle(LaunchAppearance.palette.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, height < 40 ? 5 : 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(LaunchAppearance.palette.foreground)
            .background(item.event.color.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(item.conflict ? LaunchAppearance.palette.danger : item.event.color.tint.opacity(0.3), lineWidth: item.conflict ? 1.5 : 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.event.title + ", " + item.event.start.formatted(date: .omitted, time: .shortened) + " to " + item.event.end.formatted(date: .omitted, time: .shortened) + (item.conflict ? ", overlaps another event" : ""))
        .accessibilityHint("Edit event")
    }

    private var currentTimeLine: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let components = Calendar.current.dateComponents([.hour, .minute], from: context.date)
            HStack(spacing: 0) {
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 4).padding(.vertical, 3)
                    .background(LaunchAppearance.palette.background, in: Capsule())
                    .foregroundStyle(LaunchAppearance.palette.danger)
                    .frame(width: gutter)
                Circle().fill(LaunchAppearance.palette.danger).frame(width: 6, height: 6)
                Rectangle().fill(LaunchAppearance.palette.danger).frame(height: 1)
            }
            .offset(y: CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0)) / 60 * hourHeight - 8)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var allDayEvents: [CalendarEvent] { events.filter(\.isAllDay) }
    private var placements: [TimelinePlacement] { TimelinePlacement.layout(events: events, date: date) }
    private var initialHour: Int {
        if Calendar.current.isDateInToday(date) {
            return max(0, Calendar.current.component(.hour, from: Date()) - 1)
        }
        return max(0, Int((placements.first?.start ?? 540) / 60) - 1)
    }
}

struct TimelinePlacement: Identifiable {
    let event: CalendarEvent
    let start: Double
    let end: Double
    var column = 0
    var columns = 1
    var conflict = false
    var id: UUID { event.id }

    static func layout(events: [CalendarEvent], date: Date) -> [Self] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        func minute(_ time: Date) -> Double {
            if time <= day { return 0 }
            if time >= next { return 1440 }
            let parts = calendar.dateComponents([.hour, .minute, .second], from: time)
            return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) + Double(parts.second ?? 0) / 60
        }
        let timedEvents = events.filter { !$0.isAllDay && $0.start < next && $0.end > day }
        let unsorted: [TimelinePlacement] = timedEvents.map { event in
            TimelinePlacement(event: event, start: minute(event.start), end: minute(event.end))
        }
        let items = unsorted.sorted { left, right in
            if left.start == right.start { return left.end > right.end }
            return left.start < right.start
        }
        var result: [Self] = []
        var group: [Self] = []
        var groupEnd: Double = -1
        func flush() {
            guard !group.isEmpty else { return }
            var columnEnds: [Double] = []
            for index in group.indices {
                let column = columnEnds.firstIndex(where: { $0 <= group[index].start }) ?? columnEnds.count
                group[index].column = column
                if column == columnEnds.count { columnEnds.append(group[index].end) }
                else { columnEnds[column] = group[index].end }
            }
            for index in group.indices {
                group[index].columns = columnEnds.count
                group[index].conflict = group.contains { $0.id != group[index].id && $0.start < group[index].end && $0.end > group[index].start }
            }
            result.append(contentsOf: group)
            group.removeAll()
        }
        for item in items {
            if item.start >= groupEnd { flush(); groupEnd = item.end }
            group.append(item)
            groupEnd = max(groupEnd, item.end)
        }
        flush()
        return result
    }
}
