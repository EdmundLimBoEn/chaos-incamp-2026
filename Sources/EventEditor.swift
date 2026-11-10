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
    @State private var confirmingDelete = false

    init(store: EventStore, date: Date, event: CalendarEvent? = nil) {
        self.store = store
        self.event = event
        let initialStart = event?.start ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        _reminderMinutes = State(initialValue: event?.reminderMinutes ?? -1)
        _title = State(initialValue: event?.title ?? "")
        _start = State(initialValue: initialStart)
        _end = State(initialValue: event.map { $0.isAllDay ? Calendar.current.date(byAdding: .day, value: -1, to: $0.end)! : $0.end } ?? initialStart.addingTimeInterval(3600))
        _isAllDay = State(initialValue: event?.isAllDay ?? false)
        _location = State(initialValue: event?.location ?? "")
        _notes = State(initialValue: event?.notes ?? "")
        _color = State(initialValue: event?.color ?? .teal)
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
                            .font(.caption).foregroundStyle(.red)
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
                        .font(.caption).foregroundStyle(.secondary)
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
                Section("Notes") {
                    TextField("Add notes", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section {
                    Label("Saved on this iPhone. Works offline.", systemImage: "internaldrive")
                        .font(.footnote).foregroundStyle(.secondary)
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
            .confirmationDialog("Delete this event?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete event", role: .destructive) {
                    if let event { store.delete(event) }
                    dismiss()
                }
            }
        }
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
            reminderMinutes: reminderMinutes < 0 ? nil : reminderMinutes
        ))
        dismiss()
    }
}
