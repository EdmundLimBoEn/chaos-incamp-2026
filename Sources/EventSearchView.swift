import SwiftUI

struct EventSearchView: View {
    let store: EventStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var dateFilter = "any"
    @State private var colorFilter = "any"
    @State private var tagFilter = "any"
    @State private var remindersOnly = false
    @State private var conflictsOnly = false
    @State private var showEditor = false
    @State private var editing: CalendarEvent?
    @State private var draft: CalendarEvent?
    private var parsed: EventSearchQuery { EventSearchQuery(raw: query) }
    private var tags: [String] { Array(Set(store.activeEvents.flatMap { $0.tags ?? [] })).sorted() }

    private var results: [CalendarEvent] {
        let now = Date()
        let calendar = Calendar.current
        return store.activeEvents.filter { event in
            guard parsed.matches(event) else { return false }
            if colorFilter != "any" && event.color.rawValue != colorFilter { return false }
            if tagFilter != "any" && !(event.tags ?? []).contains(tagFilter) { return false }
            if remindersOnly && event.reminderMinutes == nil { return false }
            if dateFilter == "upcoming" && event.end <= now { return false }
            if dateFilter == "today" {
                let start = calendar.startOfDay(for: now)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                if event.start >= end || event.end <= start { return false }
            }
            if conflictsOnly && !store.activeEvents.contains(where: { other in
                other.id != event.id && !other.isAllDay && !event.isAllDay && other.start < event.end && other.end > event.start
            }) { return false }
            return true
        }.sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Try “design tomorrow at 3pm”, “@Alex” or “#work”.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !query.isEmpty { Text(parsed.querySummary).font(.caption).foregroundStyle(.tint) }
                }
                Section("Filters") {
                    Picker("When", selection: $dateFilter) {
                        Text("Any date").tag("any")
                        Text("Today").tag("today")
                        Text("Upcoming").tag("upcoming")
                    }
                    Picker("Color", selection: $colorFilter) {
                        Text("Any color").tag("any")
                        ForEach(EventColor.allCases) { Text($0.rawValue.capitalized).tag($0.rawValue) }
                    }
                    if !tags.isEmpty {
                        Picker("Tag", selection: $tagFilter) {
                            Text("Any tag").tag("any")
                            ForEach(tags, id: \.self) { Text("#" + $0).tag($0) }
                        }
                    }
                    Toggle("With reminders", isOn: $remindersOnly)
                    Toggle("Overlapping events", isOn: $conflictsOnly)
                    Button("Reset filters") {
                        dateFilter = "any"; colorFilter = "any"; tagFilter = "any"
                        remindersOnly = false; conflictsOnly = false
                    }
                }
                Section("\(results.count) matching events") {
                    if results.isEmpty {
                        ContentUnavailableView("No matching events", systemImage: "magnifyingglass", description: Text("Try fewer words or reset the filters."))
                    }
                    ForEach(results) { event in
                        Button { editing = event; draft = nil; showEditor = true } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(event.color.tint).frame(width: 8, height: 8).padding(.top, 5)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(event.title).font(.headline).foregroundStyle(.primary)
                                    Text(event.start.formatted(date: .abbreviated, time: event.isAllDay ? .omitted : .shortened)).font(.caption).foregroundStyle(.secondary)
                                    let people = (event.people ?? []) + (event.hostName.map { [$0] } ?? [])
                                    if !people.isEmpty { Label(people.joined(separator: ", "), systemImage: "person.2").font(.caption).foregroundStyle(.secondary) }
                                    if !(event.tags ?? []).isEmpty { Text((event.tags ?? []).map { "#" + $0 }.joined(separator: " ")).font(.caption).foregroundStyle(.tint) }
                                }
                            }
                        }
                    }
                }
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section(results.isEmpty ? "Create what you’re looking for" : "Add something new") {
                        Button {
                            editing = nil; draft = parsed.draft(); showEditor = true
                        } label: { Label("Create “\(parsed.draft().title)”", systemImage: "plus.circle.fill") }
                        Text("Review the suggested title, date and time before saving.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Search & filter")
            .searchable(text: $query, prompt: "Events, people, dates, times, tags")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showEditor) { EventEditor(store: store, date: Date(), event: editing, draft: draft) }
        }
    }
}
