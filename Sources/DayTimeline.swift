import SwiftUI

struct DayTimeline: View {
    let events: [CalendarEvent]
    let date: Date
    let edit: (CalendarEvent) -> Void
    private let hourHeight: CGFloat = 80
    private let gutter: CGFloat = 52

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(events.filter(\.isAllDay)) { event in
                        Button { edit(event) } label: {
                            Text(event.title).font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10).foregroundStyle(event.color.tint)
                                .background(event.color.tint.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).padding(.leading, gutter)
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            ForEach(0..<24) { hour in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(String(format: "%02d:00", hour)).font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary).frame(width: gutter - 8)
                                    Rectangle().fill(.white.opacity(0.15)).frame(height: 0.5)
                                }.offset(y: CGFloat(hour) * hourHeight).id(hour)
                            }
                            ForEach(placements) { item in
                                let width = max(1, (geometry.size.width - gutter) / CGFloat(item.columns))
                                Button { edit(item.event) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        if item.conflict {
                                            Label("Overlap", systemImage: "exclamationmark.triangle.fill")
                                                .font(.system(size: 9, weight: .bold)).foregroundStyle(.red)
                                        }
                                        Text(item.event.title).font(.caption.bold()).lineLimit(2)
                                        Text(item.event.start.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 10)).lineLimit(1)
                                        Spacer(minLength: 0)
                                    }.padding(6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .foregroundStyle(item.event.color.tint)
                                        .background(item.event.color.tint.opacity(0.23), in: RoundedRectangle(cornerRadius: 7))
                                        .overlay { RoundedRectangle(cornerRadius: 7).stroke(item.conflict ? Color.red : item.event.color.tint.opacity(0.5), lineWidth: item.conflict ? 2 : 1) }
                                }.buttonStyle(.plain)
                                    .frame(width: max(1, width - 4), height: max(18, CGFloat(item.end - item.start) / 60 * hourHeight - 2))
                                    .offset(x: gutter + CGFloat(item.column) * width, y: CGFloat(item.start) / 60 * hourHeight)
                                    .accessibilityLabel(item.event.title + (item.conflict ? ", overlaps another event" : ""))
                            }
                            if Calendar.current.isDateInToday(date) {
                                TimelineView(.periodic(from: .now, by: 60)) { context in
                                    let components = Calendar.current.dateComponents([.hour, .minute], from: context.date)
                                    HStack(spacing: 0) {
                                        Text(context.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 9, weight: .bold))
                                            .padding(3).background(.red, in: Capsule()).frame(width: gutter)
                                        Rectangle().fill(.red).frame(height: 2)
                                    }.offset(y: CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0)) / 60 * hourHeight)
                                }.allowsHitTesting(false)
                            }
                        }
                    }.frame(height: hourHeight * 24)
                }.padding(.horizontal, 12)
            }.onAppear { proxy.scrollTo(8, anchor: .top) }
        }
    }

    private var placements: [TimelinePlacement] {
        TimelinePlacement.layout(events: events, date: date)
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
        let items = events.filter { !$0.isAllDay && $0.start < next && $0.end > day }
            .map { Self(event: $0, start: minute($0.start), end: minute($0.end)) }
            .sorted { $0.start == $1.start ? $0.end > $1.end : $0.start < $1.start }
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
