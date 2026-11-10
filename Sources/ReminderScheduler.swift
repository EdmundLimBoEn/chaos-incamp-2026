import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()
    private let delegate = NotificationDelegate()
    private var generation = 0

    func configure() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    func reconcile(_ events: [CalendarEvent]) async throws {
        generation += 1
        let current = generation
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard current == generation else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("event-") }.map(\.identifier))
        let range = DateInterval(start: Date(), duration: 366 * 86400)
        let expanded = events.flatMap { EventRecurrence.occurrences($0, in: range) }
        let upcoming = expanded.filter { $0.deletedAt == nil && $0.reminderMinutes != nil && $0.start.addingTimeInterval(-Double($0.reminderMinutes ?? 0) * 60) > Date() }
            .sorted { $0.start.addingTimeInterval(-Double($0.reminderMinutes ?? 0) * 60) < $1.start.addingTimeInterval(-Double($1.reminderMinutes ?? 0) * 60) }
        guard !upcoming.isEmpty else { return }
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
            throw ReminderError.denied
        }
        guard current == generation else { return }
        for event in upcoming.prefix(60) {
            guard current == generation else { return }
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.isAllDay ? "Your all-day event is coming up." : "Starts at \(event.start.formatted(date: .abbreviated, time: .shortened))\(event.location.isEmpty ? "" : " · " + event.location)"
            content.sound = .default
            content.userInfo = ["eventID": event.id.uuidString]
            let fireDate = event.start.addingTimeInterval(-Double(event.reminderMinutes ?? 0) * 60)
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate), repeats: false)
            try await center.add(UNNotificationRequest(identifier: "event-" + event.id.uuidString, content: content, trigger: trigger))
        }
    }
}

private enum ReminderError: LocalizedError {
    case denied
    var errorDescription: String? { "Event saved, but notifications are disabled. Enable them in Settings to receive reminders." }
}
