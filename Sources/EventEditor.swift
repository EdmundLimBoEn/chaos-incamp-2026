import SwiftUI

struct EventEditor: View {
    let store: EventStore
    let event: CalendarEvent?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var notes: String
    @State private var color: EventColor
    @State private var reminderMinutes: Int
    @State private var people: String
    @State private var tags: String
    @State private var hostName: String
    @State private var recurrence: String
    @State private var repeatEnds: Bool
    @State private var recurrenceUntil: Date
    @State private var confirmingDelete = false

    init(store: EventStore, date: Date, event: CalendarEvent? = nil, draft: CalendarEvent? = nil) {
        self.store = store
        self.event = event.map { store.sourceEvent($0) }
        let initial = self.event ?? draft
        _recurrence = State(initialValue: initial?.recurrence ?? "none")
        _repeatEnds = State(initialValue: initial?.recurrenceUntil != nil)
        _recurrenceUntil = State(initialValue: initial?.recurrenceUntil ?? Calendar.current.date(byAdding: .month, value: 3, to: date)!)
        _people = State(initialValue: (initial?.people ?? []).joined(separator: ", "))
        _tags = State(initialValue: (initial?.tags ?? []).joined(separator: ", "))
        _hostName = State(initialValue: initial?.hostName ?? "")
        let initialStart = initial?.start ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        _reminderMinutes = State(initialValue: initial?.reminderMinutes ?? -1)
        _title = State(initialValue: initial?.title ?? "")
        _start = State(initialValue: initialStart)
        _end = State(initialValue: initial.map { $0.isAllDay ? Calendar.current.date(byAdding: .day, value: -1, to: $0.end)! : $0.end } ?? initialStart.addingTimeInterval(3600))
        _isAllDay = State(initialValue: initial?.isAllDay ?? false)
        _location = State(initialValue: initial?.location ?? "")
        _notes = State(initialValue: initial?.notes ?? "")
        _color = State(initialValue: initial?.color ?? .teal)
    }

    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (isAllDay ? Calendar.current.startOfDay(for: end) >= Calendar.current.startOfDay(for: start) : end > start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Event title", text: $title)
                        .font(.title3.weight(.semibold))
                    TextField("Location", text: $location)
                }
                Section("When") {
                    Toggle("All day", isOn: $isAllDay)
                    DatePicker("Starts", selection: $start, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("Ends", selection: $end, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    if !isAllDay && end <= start {
                        Text("Choose an end after the start.")
                            .font(.caption).foregroundStyle(LaunchAppearance.palette.danger)
                    }
                }
                Section("Repeat") {
                    Picker("Repeats", selection: $recurrence) {
                        Text("Never").tag("none")
                        Text("Every day").tag("daily")
                        Text("Every week").tag("weekly")
                        Text("Every month").tag("monthly")
                    }
                    if recurrence != "none" {
                        Toggle("End repeat on a date", isOn: $repeatEnds)
                        if repeatEnds { DatePicker("Last day", selection: $recurrenceUntil, in: Calendar.current.startOfDay(for: start)..., displayedComponents: .date) }
                        Text("Changes and deletion apply to the entire series.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Reminder") {
                    Picker("Notify me", selection: $reminderMinutes) {
                        Text("None").tag(-1)
                        Text("At start").tag(0)
                        Text("5 minutes before").tag(5)
                        Text("15 minutes before").tag(15)
                        Text("30 minutes before").tag(30)
                        Text("1 hour before").tag(60)
                        Text("1 day before").tag(1440)
                    }
                    Text("Local notifications work offline. Delivery follows your notification and Focus settings.")
                        .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                }
                Section("Color") {
                    HStack(spacing: 20) {
                        ForEach(EventColor.allCases) { option in
                            Button {
                                color = option
                            } label: {
                                Circle().fill(option.tint)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if color == option {
                                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.rawValue.capitalized)
                            .accessibilityAddTraits(color == option ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("People & tags") {
                    TextField("People, separated by commas", text: $people)
                    TextField("Host name", text: $hostName)
                    TextField("Tags, separated by commas", text: $tags)
                        .textInputAutocapitalization(.never)
                }
                Section("Notes") {
                    TextField("Add notes", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section {
                    Label("Saved on this iPhone. Works offline.", systemImage: "internaldrive")
                        .font(.footnote).foregroundStyle(LaunchAppearance.palette.secondary)
                }
                if event != nil {
                    Section {
                        Button("Delete event", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(event == nil ? "New event" : "Edit event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold).disabled(!valid)
                }
            }
            .confirmationDialog(recurrence == "none" ? "Delete this event?" : "Delete the entire repeating series?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete event", role: .destructive) {
                    if let event { store.delete(event) }
                    dismiss()
                }
            }
        }
    }

    private func split(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func save() {
        guard valid else { return }
        store.upsert(CalendarEvent(
            id: event?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            start: isAllDay ? Calendar.current.startOfDay(for: start) : start,
            end: isAllDay ? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end))! : end,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            color: color,
            updatedAt: Date(),
            deletedAt: nil,
            reminderMinutes: reminderMinutes < 0 ? nil : reminderMinutes,
            people: split(people),
            tags: split(tags).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "#")) },
            hostName: hostName.trimmingCharacters(in: .whitespacesAndNewlines),
            recurrence: recurrence == "none" ? nil : recurrence,
            recurrenceUntil: recurrence != "none" && repeatEnds ? max(start, recurrenceUntil) : nil
        ))
        dismiss()
    }
}
