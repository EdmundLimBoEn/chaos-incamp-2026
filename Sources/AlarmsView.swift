import AlarmKit
import SwiftUI
import UIKit

@available(iOS 26.0, *)
private struct CalendarAlarmMetadata: AlarmMetadata {
    var title: String
}

struct AlarmsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        if #available(iOS 26.0, *) {
            AlarmKitView()
        } else {
            NavigationStack {
                VStack(spacing: 16) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(context.date, style: .time)
                            .font(.system(size: 52, weight: .light, design: .rounded))
                    }
                    Text("Alarms require iOS 26 or later.")
                    Text("Event reminders still work on this device.")
                        .foregroundStyle(LaunchAppearance.palette.secondary)
                }
                .navigationTitle("Clock")
                .toolbar { Button("Done") { dismiss() } }
            }
        }
    }
}

@available(iOS 26.0, *)
private struct AlarmKitView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date().addingTimeInterval(300)
    @State private var title = "Time to get going"
    @State private var alarms: [Alarm] = []
    @State private var error: String?
    @State private var scheduling = false
    @State private var failureStage = "Read alarms"
    @AppStorage("alarmTitles") private var savedTitles = Data()

    private var titles: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: savedTitles)) ?? [:]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(spacing: 8) {
                            Text(context.date, style: .time)
                                .font(.system(size: 52, weight: .light, design: .rounded))
                                .monospacedDigit()
                            Text(TimeZone.current.identifier.replacingOccurrences(of: "_", with: " "))
                                .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                }
                Section("New alarm") {
                    TextField("Label", text: $title)
                    DatePicker("Ring at", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Button {
                        Task { await schedule() }
                    } label: {
                        Label(scheduling ? "Scheduling…" : "Set alarm", systemImage: "alarm.fill")
                    }.disabled(scheduling || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Your alarms") {
                    if alarms.isEmpty {
                        Text("No alarms set").foregroundStyle(LaunchAppearance.palette.secondary)
                    }
                    ForEach(alarms) { alarm in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(titles[alarm.id.uuidString] ?? "Alarm").font(.headline)
                                Text(scheduleLabel(alarm)).font(.subheadline).foregroundStyle(LaunchAppearance.palette.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) { cancel(alarm) } label: {
                                Image(systemName: "trash")
                            }.accessibilityLabel("Cancel alarm")
                        }
                    }
                }
                Section {
                    Button("Open alarm permissions in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Text("Alarms use Apple AlarmKit. Permission is requested when you set your first alarm.")
                        .font(.footnote).foregroundStyle(LaunchAppearance.palette.secondary)
                }
            }
            .navigationTitle("Clock & alarms")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                refresh()
                for await updates in AlarmManager.shared.alarmUpdates {
                    alarms = updates
                }
            }
            .alert("Alarm couldn’t be set", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    @MainActor
    private func schedule() async {
        scheduling = true
        defer { scheduling = false }
        do {
            failureStage = "Request alarm permission"
            let manager = AlarmManager.shared
            let authorization = manager.authorizationState == .notDetermined
                ? try await manager.requestAuthorization()
                : manager.authorizationState
            guard authorization == .authorized else {
                error = "Allow alarms for this app in Settings to schedule an alarm."
                return
            }
            guard date > Date() else {
                error = "Choose a time in the future."
                return
            }
            let label = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let presentation = AlarmPresentation(alert: . init(title: LocalizedStringResource(stringLiteral: label)))
            let attributes = AlarmAttributes(presentation: presentation, metadata: CalendarAlarmMetadata(title: label), tintColor: .red)
            let id = UUID()
            let configuration = AlarmManager.AlarmConfiguration<CalendarAlarmMetadata>.alarm(schedule: .fixed(date), attributes: attributes)
            failureStage = "Schedule alarm"
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            var updated = titles
            updated[id.uuidString] = label
            savedTitles = (try? JSONEncoder().encode(updated)) ?? savedTitles
            refresh()
        } catch {
            self.error = describe(error, operation: failureStage)
        }
    }

    private func refresh() {
        guard AlarmManager.shared.authorizationState == .authorized else {
            alarms = []
            return
        }
        do { alarms = try AlarmManager.shared.alarms }
        catch { self.error = describe(error, operation: "Read alarms") }
    }

    private func cancel(_ alarm: Alarm) {
        do {
            try AlarmManager.shared.cancel(id: alarm.id)
            var updated = titles
            updated.removeValue(forKey: alarm.id.uuidString)
            savedTitles = (try? JSONEncoder().encode(updated)) ?? savedTitles
            refresh()
        } catch { self.error = describe(error, operation: "Cancel alarm") }
    }

    private func describe(_ error: Error, operation: String) -> String {
        if let alarmError = error as? AlarmManager.AlarmError, alarmError == .maximumLimitReached {
            return "The system alarm limit has been reached. Cancel an existing alarm before adding another."
        }
        let detail = error as NSError
        return "\(operation) failed. \(detail.localizedDescription)\n\(detail.domain) (\(detail.code))\nPermission: \(String(describing: AlarmManager.shared.authorizationState))"
    }

    private func scheduleLabel(_ alarm: Alarm) -> String {
        switch alarm.schedule {
        case .fixed(let date): date.formatted(date: .abbreviated, time: .shortened)
        case .relative(let relative): String(format: "%02d:%02d", relative.time.hour, relative.time.minute)
        case nil: "Timer"
        @unknown default: "Alarm"
        }
    }
}
