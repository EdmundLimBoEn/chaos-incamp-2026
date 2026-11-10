import SwiftUI

private enum CalendarMode: String, CaseIterable { case year = "Year", month = "Month", day = "Day" }

struct CalendarView: View {
    @Bindable var store: EventStore
    @AppStorage("accentColor") private var accentKey = "red"
    @AppStorage("compactCalendar") private var compact = false
    @AppStorage("secondaryCalendar") private var secondaryCalendar = "none"
    @State private var appearance = false
    @State private var discover = false
    @State private var calendarSystems = false
    private var accent: Color { CalendarAppearance.accent(accentKey) }
    @State private var selected = Date()
    @State private var mode = CalendarMode.month
    @State private var alarms = false
    @State private var editor = false
    @State private var editing: CalendarEvent?
    @State private var search = ""
    @State private var searching = false
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                switch mode {
                case .year: yearView
                case .month: monthView
                case .day: dayView
                }
            }
            .background(Color(uiColor: .systemBackground))
            .safeAreaInset(edge: .bottom) { bottomBar }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $searching) { EventSearchView(store: store) }
            .sheet(isPresented: $discover) { PublicEventsView(store: store) }
            .sheet(isPresented: $appearance) { AppearanceView() }
            .sheet(isPresented: $calendarSystems) { CalendarSystemsView() }
            .sheet(isPresented: $alarms) { AlarmsView() }
            .sheet(isPresented: $editor) { EventEditor(store: store, date: selected, event: editing) }
            .alert("Couldn’t save changes", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("On this device", systemImage: "internaldrive")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Discover public events", systemImage: "globe") { discover = true }
                    Button("Appearance", systemImage: "paintpalette") { appearance = true }
                    Button("Calendar systems", systemImage: "moonphase.waning.crescent") { calendarSystems = true }
                } label: { Image(systemName: "slider.horizontal.3").frame(width: 36, height: 40) }
                Button { alarms = true } label: { Image(systemName: "alarm").frame(width: 40, height: 40) }.accessibilityLabel("Clocks and alarms")
                Button { searching.toggle() } label: { Image(systemName: "magnifyingglass").frame(width: 40, height: 40) }
                    .accessibilityLabel("Search events")
                Button { editing = nil; editor = true } label: { Image(systemName: "plus").font(.title2).frame(width: 40, height: 40) }
                    .accessibilityLabel("Add event")
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selected.formatted(.dateTime.year())).font(.subheadline).foregroundStyle(accent)
                    if let secondary = CalendarSystems.label(for: selected, system: secondaryCalendar) {
                        Text(secondary).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(mode == .year ? "Your year" : selected.formatted(.dateTime.month(.wide)))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                }
                Spacer()
                Button { move(-1) } label: { Image(systemName: "chevron.left").padding(10) }.accessibilityLabel("Previous")
                Button { move(1) } label: { Image(systemName: "chevron.right").padding(10) }.accessibilityLabel("Next")
            }
            Picker("Calendar view", selection: $mode) {
                ForEach(CalendarMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
        }.padding(20)
    }

    private var yearView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 28) {
                ForEach(1...12, id: \.self) { month in
                    let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: selected), month: month, day: 1))!
                    Button { selected = date; mode = .month } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(date.formatted(.dateTime.month(.abbreviated))).font(.headline).foregroundStyle(accent)
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(Array(days(in: date).enumerated()), id: \.offset) { _, day in
                                    Text(day.map { String(calendar.component(.day, from: $0)) } ?? " ")
                                        .font(.system(size: 9, weight: .medium)).frame(maxWidth: .infinity)
                                        .foregroundStyle(day.map { calendar.isDateInToday($0) } == true ? accent : .primary)
                                }
                            }
                        }.frame(height: 135, alignment: .top)
                    }.buttonStyle(.plain)
                }
            }.padding(20)
        }
    }

    private var monthView: some View {
        ScrollView {
            VStack(spacing: 0) {
                weekdayLabels
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(Array(days(in: selected).enumerated()), id: \.offset) { _, date in
                        if let date {
                            Button { selected = date; mode = .day } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(String(calendar.component(.day, from: date)))
                                        .font(.system(size: 19, weight: .medium))
                                        .frame(width: 34, height: 34)
                                        .background(calendar.isDateInToday(date) ? accent : Color.clear, in: Circle())
                                    ForEach(store.events(on: date).prefix(3)) { event in
                                        Text(event.title).font(.system(size: 9, weight: .semibold))
                                            .lineLimit(1).padding(.horizontal, 3).padding(.vertical, 3)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .foregroundStyle(event.color.tint)
                                            .background(event.color.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: compact ? 82 : 110, maxHeight: compact ? 82 : 110, alignment: .topLeading)
                                .padding(.top, 9)
                                .overlay(alignment: .top) { Rectangle().fill(.primary.opacity(0.15)).frame(height: 0.5) }
                            }.buttonStyle(.plain)
                        } else { Color.clear.frame(height: compact ? 82 : 110) }
                    }
                }
                if store.events(on: selected).isEmpty {
                    Text("Room for something good.").foregroundStyle(.secondary).padding(.top, 28)
                }
            }.padding(.horizontal, 12)
        }
    }

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(0..<7) { index in
                let symbol = calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7]
                Text(symbol).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }.padding(.vertical, 12)
    }

    private var dayView: some View {
        VStack(spacing: 0) {
            Text(selected.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                .font(.headline).padding(.bottom, 14)
            DayTimeline(events: store.events(on: selected), date: selected) { event in
                editing = event
                editor = true
            }
        }
    }

    private func eventButton(_ event: CalendarEvent) -> some View {
        Button { editing = event; editor = true } label: {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 2).fill(event.color.tint).frame(width: 3)
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title).font(.headline)
                    Text(event.isAllDay ? "All day" : "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                    if !event.location.isEmpty { Label(event.location, systemImage: "location").font(.caption) }
                }
                Spacer(minLength: 0)
            }.padding(10).foregroundStyle(event.color.tint)
                .background(event.color.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(store.activeEvents.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.notes.localizedCaseInsensitiveContains(search) }.sorted { $0.start < $1.start }) { event in
                    VStack(alignment: .leading) {
                        Text(event.start.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                        eventButton(event)
                    }
                }
            }.padding()
        }
    }

    private var bottomBar: some View {
        HStack {
            Button("Today") { selected = Date(); searching = false }.font(.headline)
            Spacer()
            Text("sstincky calander").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            Button { editing = nil; editor = true } label: { Label("Event", systemImage: "plus") }.font(.headline)
        }.padding(.horizontal, 24).padding(.vertical, 16).background(.ultraThinMaterial, in: Capsule()).padding(.horizontal, 18).padding(.bottom, 8)
    }

    private func move(_ value: Int) {
        selected = calendar.date(byAdding: mode == .year ? .year : mode == .month ? .month : .day, value: value, to: selected) ?? selected
    }
    private func displayHour(_ event: CalendarEvent) -> Int {
        calendar.isDate(event.start, inSameDayAs: selected) ? calendar.component(.hour, from: event.start) : 0
    }
    private func days(in date: Date) -> [Date?] {
        let start = calendar.dateInterval(of: .month, for: date)!.start
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: date)!.count
        return Array(repeating: nil, count: offset) + (0..<count).map { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
