import Foundation

struct WidgetEventSnapshot: Codable {
    static let group = "group.systems.edmundlim.daymark"
    static let kind = "UpcomingCalendarEvents"
    let events: [CalendarEvent]

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("widget-events.json")
    }

    static func read() -> [CalendarEvent]? {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        return snapshot.events
    }

    static func write(_ events: [CalendarEvent]) throws {
        guard let url = fileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        // The widget only needs upcoming event titles and times, not private notes.
        let upcoming = events.filter { $0.deletedAt == nil && $0.end > Date() }.map { event in
            var copy = event
            copy.notes = ""
            copy.people = nil
            copy.hostName = nil
            copy.tags = nil
            copy.location = ""
            return copy
        }
        try JSONEncoder().encode(Self(events: upcoming)).write(to: url, options: .atomic)
    }
}
