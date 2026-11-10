import SwiftUI

private enum CalendarMode: String, CaseIterable {
    case week = "Week", month = "Month", day = "Day", year = "Year"
}

private struct CalendarEditorSelection: Identifiable {
    let id = UUID()
    let event: CalendarEvent?
    let draft: CalendarEvent?
}

struct CalendarView: View {
    @Bindable var store: EventStore
    @AppStorage("paletteRevision") private var revision = 0
    @AppStorage("accentColor") private var accentKey = "red"
    @AppStorage("compactCalendar") private var compact = false
    @AppStorage("secondaryCalendar") private var secondaryCalendar = "none"
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected = Date()
    @State private var mode = CalendarMode.day
    @State private var appearance = false
    @State private var calendarSystems = false
    @State private var alarms = false
    @State private var searching = false
    @State private var publishEvent = false
    @State private var editor: CalendarEditorSelection?
    private let calendar = Calendar.current
    private var accent: Color { CalendarAppearance.accent(accentKey) }
    private var palette: LaunchPalette { LaunchAppearance.palette }
    private var selectedEvents: [CalendarEvent] { store.events(on: selected) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controlsRow
                switch mode {
                case .week: weekView
                case .year: yearView
                case .month: monthView
                case .day: dayView
                }
            }
            .calendarTheme()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") { select(Date()) }.font(.subheadline.weight(.semibold))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Search events", systemImage: "magnifyingglass") { searching = true }
                    optionsMenu
                    Button("New event", systemImage: "plus") { createEvent() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $searching) { EventSearchView(store: store) }
            .sheet(isPresented: $publishEvent) { PublicEventComposer(store: store) }
            .sheet(isPresented: $appearance) { AppearanceView() }
            .sheet(isPresented: $calendarSystems) { CalendarSystemsView() }
            .sheet(isPresented: $alarms) { AlarmsView() }
            .sheet(item: $editor) { selection in
                EventEditor(store: store, date: selected, event: selection.event, draft: selection.draft)
                    .id(selection.id)
            }
            .alert("Calendar notice", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }

    private var optionsMenu: some View {
        Menu("Calendar options", systemImage: "ellipsis") {
            Button("Appearance") { appearance = true }
            Button("Alarms") { alarms = true }
            Button("Calendars") { calendarSystems = true }
            Divider()
            Button("Publish event") { publishEvent = true }
        }
    }

    private var controlsRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(mode == .year ? selected.formatted(.dateTime.year()) : selected.formatted(.dateTime.month(.abbreviated).year()))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.foreground)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Menu {
                    Picker("Calendar view", selection: $mode) {
                        ForEach(CalendarMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(mode.rawValue).font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                    }.frame(minHeight: 44)
                }
                .accessibilityLabel("Calendar view, \(mode.rawValue)")
                HStack(spacing: 0) {
                    Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Previous \(mode.rawValue.lowercased())")
                    Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .accessibilityLabel("Next \(mode.rawValue.lowercased())")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.foreground)
            }
            if let secondary = CalendarSystems.label(for: selected, system: secondaryCalendar) {
                Text(secondary).font(.caption).foregroundStyle(palette.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 4)
        .frame(maxWidth: 1100).frame(maxWidth: .infinity)
    }

    private var weekView: some View {
        VStack(spacing: 8) {
            weekStrip
            ScrollView {
                agenda
                    .padding(.horizontal, 16).padding(.bottom, 20)
                    .frame(maxWidth: 800).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
        }
        .simultaneousGesture(daySwipe)
    }

    private var monthView: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    monthCard.frame(minWidth: 340, maxWidth: .infinity)
                    agenda.frame(minWidth: 320, maxWidth: .infinity)
                }
                VStack(spacing: 14) {
                    monthCard
                    agenda
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 20)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var monthCard: some View {
        VStack(spacing: 8) {
            weekdayLabels
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: compact ? 0 : 2) {
                ForEach(monthDates(for: selected), id: \.self) { date in
                    let events = store.events(on: date)
                    CalendarDateButton(date: date, selected: selected, events: events, inCurrentMonth: calendar.isDate(date, equalTo: selected, toGranularity: .month), compact: compact, accent: accent) {
                        select(date)
                    }
                }
            }
        }
        .padding(.horizontal, 8).padding(.top, 12).padding(.bottom, 10)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(0..<7) { index in
                let symbol = calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7]
                Text(symbol).font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary).frame(maxWidth: .infinity)
            }
        }.padding(.bottom, 2)
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(calendar.isDateInToday(selected) ? "Today" : selected.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline.weight(.semibold)).foregroundStyle(palette.foreground)
            if selectedEvents.isEmpty { emptyAgenda }
            else {
                LazyVStack(spacing: 8) {
                    ForEach(selectedEvents) { event in
                        CalendarAgendaRow(event: event, conflict: overlaps(event)) {
                            editor = CalendarEditorSelection(event: event, draft: nil)
                        }
                    }
                }
            }
        }
    }

    private var emptyAgenda: some View {
        HStack {
            Text("No events").font(.subheadline).foregroundStyle(palette.secondary)
            Spacer()
            Button("Add event") { createEvent() }
                .font(.subheadline.weight(.semibold)).buttonStyle(.bordered)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var yearView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: sizeClass == .regular ? 3 : 2), spacing: 14) {
                ForEach(1...12, id: \.self) { month in
                    let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: selected), month: month, day: 1))!
                    Button { selected = date; mode = .month } label: {
                        miniMonth(date)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(.dateTime.month(.wide).year()))
                    .accessibilityHint("Open month")
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
            .frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.scrollIndicators(.hidden)
    }

    private func miniMonth(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(date.formatted(.dateTime.month(.abbreviated))).font(.headline)
                Spacer(minLength: 0)
                if calendar.isDate(date, equalTo: Date(), toGranularity: .month) {
                    Circle().fill(accent).frame(width: 6, height: 6)
                }
            }.foregroundStyle(palette.foreground)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 5) {
                ForEach(monthDates(for: date), id: \.self) { day in
                    Text(calendar.isDate(day, equalTo: date, toGranularity: .month) ? String(calendar.component(.day, from: day)) : " ")
                        .font(.system(size: 11, weight: calendar.isDateInToday(day) ? .bold : .regular))
                        .foregroundStyle(calendar.isDateInToday(day) ? accent : palette.secondary)
                        .frame(maxWidth: .infinity, minHeight: 14)
                }
            }.accessibilityHidden(true)
            Spacer(minLength: 0)
        }
        .padding(14).frame(height: 172, alignment: .top)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private var dayView: some View {
        VStack(spacing: 8) {
            weekStrip
            Text(selected.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.foreground)
            Divider()
            DayTimeline(events: selectedEvents, date: selected) { event in
                editor = CalendarEditorSelection(event: event, draft: nil)
            }
        }
        .simultaneousGesture(daySwipe)
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                Button { select(date) } label: {
                    VStack(spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.medium)).foregroundStyle(palette.secondary)
                        Text(String(calendar.component(.day, from: date)))
                            .font(.body.weight(.semibold)).frame(width: 34, height: 34)
                            .foregroundStyle(calendar.isDate(date, inSameDayAs: selected) ? LaunchAppearance.accentForeground : palette.foreground)
                            .background(calendar.isDate(date, inSameDayAs: selected) ? accent : .clear, in: Circle())
                    }.frame(maxWidth: .infinity, minHeight: 54)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                    .accessibilityAddTraits(calendar.isDate(date, inSameDayAs: selected) ? .isSelected : [])
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, 16)
        .frame(maxWidth: 800).frame(maxWidth: .infinity)
    }

    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) >= 40, abs(horizontal) > abs(vertical) * 1.3 else { return }
                if let date = calendar.date(byAdding: .day, value: horizontal > 0 ? -1 : 1, to: selected) {
                    select(date)
                }
            }
    }

    private var weekDates: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selected)!.start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func monthDates(for date: Date) -> [Date] {
        let start = calendar.dateInterval(of: .month, for: date)!.start
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: date)!.count
        let slots = ((offset + count + 6) / 7) * 7
        return (0..<slots).compactMap { calendar.date(byAdding: .day, value: $0 - offset, to: start) }
    }

    private func overlaps(_ event: CalendarEvent) -> Bool {
        !event.isAllDay && selectedEvents.contains { other in
            other.id != event.id && !other.isAllDay && other.start < event.end && other.end > event.start
        }
    }

    private func move(_ value: Int) {
        let unit: Calendar.Component
        switch mode {
        case .week: unit = .weekOfYear
        case .month: unit = .month
        case .day: unit = .day
        case .year: unit = .year
        }
        if let date = calendar.date(byAdding: unit, value: value, to: selected) { select(date) }
    }

    private func select(_ date: Date) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { selected = date }
    }

    private func createEvent() {
        let start: Date
        if calendar.isDateInToday(selected) {
            let nextHour = Date().addingTimeInterval(3600)
            start = calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
        } else {
            start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selected) ?? selected
        }
        let draft = CalendarEvent(title: "", start: start, end: start.addingTimeInterval(3600))
        editor = CalendarEditorSelection(event: nil, draft: draft)
    }
}

private struct CalendarDateButton: View {
    let date: Date
    let selected: Date
    let events: [CalendarEvent]
    let inCurrentMonth: Bool
    let compact: Bool
    let accent: Color
    let action: () -> Void
    private let calendar = Calendar.current
    private var isSelected: Bool { calendar.isDate(date, inSameDayAs: selected) }
    private var isToday: Bool { calendar.isDateInToday(date) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(String(calendar.component(.day, from: date)))
                    .font(.body.weight(isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(isSelected ? LaunchAppearance.accentForeground : isToday ? accent : LaunchAppearance.palette.foreground.opacity(inCurrentMonth ? 1 : 0.3))
                    .frame(width: 34, height: 34)
                    .background(isSelected ? accent : .clear, in: Circle())
                    .overlay { Circle().stroke(isToday && !isSelected ? accent.opacity(0.6) : .clear, lineWidth: 1.5) }
                HStack(spacing: 3) {
                    ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, event in
                        Circle().fill(isSelected ? accent : event.color.tint).frame(width: 4, height: 4)
                    }
                }.frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted) + ", \(events.count) events")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Show this day’s schedule")
    }
}

private struct CalendarAgendaRow: View {
    let event: CalendarEvent
    let conflict: Bool
    let action: () -> Void
    private var palette: LaunchPalette { LaunchAppearance.palette }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(palette.foreground)
                    if !event.isAllDay {
                        Text(event.end.formatted(date: .omitted, time: .shortened))
                            .font(.caption).foregroundStyle(palette.secondary)
                    }
                }.monospacedDigit().frame(width: 58, alignment: .leading)
                RoundedRectangle(cornerRadius: 2).fill(event.color.tint).frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.body.weight(.semibold)).foregroundStyle(palette.foreground)
                        .multilineTextAlignment(.leading).lineLimit(2)
                    if !event.location.isEmpty || conflict {
                        HStack(spacing: 6) {
                            if !event.location.isEmpty {
                                Text(event.location).foregroundStyle(palette.secondary).lineLimit(1)
                            }
                            if !event.location.isEmpty && conflict { Text("·").foregroundStyle(palette.secondary) }
                            if conflict { Text("Overlaps").foregroundStyle(palette.danger).fixedSize() }
                        }.font(.caption)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 44, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edit event")
    }
}
