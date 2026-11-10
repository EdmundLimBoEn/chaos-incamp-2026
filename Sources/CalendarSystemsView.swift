import SwiftUI

/// Secondary date labels share the same instant as the main calendar.
enum CalendarSystems {
    struct System: Identifiable {
        let id: String
        let name: String
        let kind: String
        let identifier: Calendar.Identifier
    }

    static let all: [System] = [
        System(id: "gregorian", name: "Gregorian", kind: "Solar", identifier: .gregorian),
        System(id: "chinese", name: "Chinese", kind: "Lunisolar", identifier: .chinese),
        System(id: "islamicUmmAlQura", name: "Islamic · Umm al-Qura", kind: "Lunar", identifier: .islamicUmmAlQura),
        System(id: "hebrew", name: "Hebrew", kind: "Lunisolar", identifier: .hebrew),
        System(id: "buddhist", name: "Buddhist", kind: "Solar", identifier: .buddhist),
        System(id: "persian", name: "Persian", kind: "Solar", identifier: .persian),
        System(id: "indian", name: "Indian national", kind: "Solar", identifier: .indian),
        System(id: "japanese", name: "Japanese", kind: "Solar · era years", identifier: .japanese)
    ]

    static func label(for date: Date, system: String) -> String? {
        guard let system = all.first(where: { $0.id == system }) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = Calendar(identifier: system.identifier)
        formatter.setLocalizedDateFormatFromTemplate("GyMMMMd")
        return formatter.string(from: date)
    }

    static func title(for system: String) -> String? {
        all.first(where: { $0.id == system })?.name
    }
}

struct CalendarSystemsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("secondaryCalendar") private var secondaryCalendar = "none"
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Secondary date") {
                    Picker("Show alongside your calendar", selection: $secondaryCalendar) {
                        Text("None").tag("none")
                        ForEach(CalendarSystems.all) { system in
                            Text(system.name).tag(system.id)
                        }
                    }
                    Text("Events keep their original dates and times. This adds a second date label.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Compare dates") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Button("Today") { date = Date() }
                }
                Section {
                    ForEach(CalendarSystems.all) { system in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(system.name).font(.headline)
                                Spacer()
                                Text(system.kind).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(CalendarSystems.label(for: date, system: system.id) ?? "")
                                .font(.subheadline)
                        }.padding(.vertical, 3)
                    }
                } footer: {
                    Text("Dates use Apple’s calendar calculations and your device time zone. Religious observances may differ by local practice.")
                }
            }
            .navigationTitle("Calendar systems")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
