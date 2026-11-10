import Foundation
import Observation
import WidgetKit

@MainActor @Observable
final class EventStore {
    private(set) var events: [CalendarEvent] = []
    var errorMessage: String?
    private let fileURL: URL
    private var canPersist = true

    init() {
        let directory = URL.applicationSupportDirectory.appending(path: "ChaosCalendar", directoryHint: .isDirectory)
        fileURL = directory.appending(path: "events.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                events = try JSONDecoder().decode([CalendarEvent].self, from: Data(contentsOf: fileURL))
            } else {
                events = Self.samples()
                try persist(events)
            }
            publishWidget()
        } catch {
            canPersist = false
            errorMessage = "Your calendar could not be loaded. Existing data has been preserved. \(error.localizedDescription)"
        }
    }

    var activeEvents: [CalendarEvent] {
        events.filter { $0.deletedAt == nil }.sorted { $0.start < $1.start }
    }

    func events(on date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return activeEvents.filter { $0.start < end && $0.end > start }
    }

    func upsert(_ event: CalendarEvent) {
        var updated = event
        updated.updatedAt = Date()
        updated.deletedAt = nil
        var next = events
        if let index = next.firstIndex(where: { $0.id == event.id }) {
            next[index] = updated
        } else {
            next.append(updated)
        }
        save(next)
    }

    func delete(_ event: CalendarEvent) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        var next = events
        // Retain stable IDs and deletion timestamps for a future sync adapter.
        next[index].deletedAt = Date()
        next[index].updatedAt = Date()
        save(next)
    }

    private func save(_ next: [CalendarEvent]) {
        guard canPersist else {
            errorMessage = "Calendar storage is unavailable. Restart the app after resolving the storage issue."
            return
        }
        do {
            try persist(next)
            events = next
            errorMessage = nil
            publishWidget()
            refreshReminders()
        } catch {
            errorMessage = "Changes could not be saved. \(error.localizedDescription)"
        }
    }

    private func publishWidget() {
        do {
            try WidgetEventSnapshot.write(events)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetEventSnapshot.kind)
        } catch {
            // Calendar saves remain independent of optional widget provisioning.
            print("Widget snapshot unavailable: \(error.localizedDescription)")
        }
    }

    func refreshReminders() {
        Task {
            do { try await ReminderScheduler.shared.reconcile(events) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func persist(_ next: [CalendarEvent]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(next).write(to: fileURL, options: .atomic)
    }

    private static func samples() -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }
        return [
            CalendarEvent(title: "INCamp · Build something great", start: time(8, 30), end: time(10), location: "Innovation studio", notes: "Start with an idea. Make it real.", color: .teal),
            CalendarEvent(title: "Design sprint", start: time(10, 30), end: time(12), location: "Team space", color: .purple),
            CalendarEvent(title: "Lunch & recharge", start: time(12), end: time(13), color: .orange),
            CalendarEvent(title: "Prototype review", start: time(15), end: time(16), notes: "Bring the first working draft.", color: .blue)
        ]
    }
}
