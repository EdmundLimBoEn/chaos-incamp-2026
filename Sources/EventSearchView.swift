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
    @State private var interpreted: EventSearchQuery?
    @State private var interpretedInput = ""
    @State private var intelligenceStatus = ""
    @State private var interpreting = false
    @State private var discover = false
    private var parsed: EventSearchQuery {
        interpretedInput == query ? (interpreted ?? EventSearchQuery(raw: query)) : EventSearchQuery(raw: query)
    }
    private var tags: [String] { Array(Set(store.activeEvents.flatMap { $0.tags ?? [] })).sorted() }

    private var results: [CalendarEvent] {
        let now = Date()
        let calendar = Calendar.current
        return store.searchEvents(in: parsed.interval).filter { event in
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
            if conflictsOnly && !store.searchEvents(in: parsed.interval).contains(where: { other in
                other.id != event.id && !other.isAllDay && !event.isAllDay && other.start < event.end && other.end > event.start
            }) { return false }
            return true
        }.sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty { PublicDiscoveryPreview(store: store) }
                Section {
                    Button("Discover public events", systemImage: "globe") { discover = true }
                    Text("Try “design tomorrow at 3pm”, “@Alex” or “#work”.")
                        .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                    if !query.isEmpty {
                        Text(parsed.querySummary).font(.caption).foregroundStyle(.tint)
                        if interpreting { ProgressView("Understanding your request…").font(.caption) }
                        else if !intelligenceStatus.isEmpty { Text(intelligenceStatus).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary) }
                    }
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
                                    Text(event.title).font(.headline).foregroundStyle(LaunchAppearance.palette.foreground)
                                    Text(event.start.formatted(date: .abbreviated, time: event.isAllDay ? .omitted : .shortened)).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                                    let people = (event.people ?? []) + (event.hostName.map { [$0] } ?? [])
                                    if !people.isEmpty { Label(people.joined(separator: ", "), systemImage: "person.2").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary) }
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
                        Text(parsed.draft().start.formatted(date: .complete, time: .shortened))
                            .font(.subheadline).foregroundStyle(LaunchAppearance.palette.secondary)
                        if !(parsed.draft().people ?? []).isEmpty {
                            Text("With " + (parsed.draft().people ?? []).joined(separator: ", ")).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                        }
                        Text("Review the suggested title, date and time before saving.").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                    }
                }
            }
            .navigationTitle("Search & filter")
            .searchable(text: $query, prompt: "Events, people, dates, times, tags")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $discover) { PublicEventsView(store: store) }
            .task(id: query) {
                interpreted = nil
                interpretedInput = ""
                intelligenceStatus = ""
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { interpreting = false; return }
                interpreting = true
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                let input = query
                let result = await IntelligentEventParser.interpret(input)
                guard !Task.isCancelled, query == input else { return }
                interpreted = result.query
                interpretedInput = input
                intelligenceStatus = result.status
                interpreting = false
            }
            .sheet(isPresented: $showEditor) { EventEditor(store: store, date: Date(), event: editing, draft: draft) }
        }
    }
}
