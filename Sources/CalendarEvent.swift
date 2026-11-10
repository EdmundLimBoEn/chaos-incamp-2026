import Foundation
import CryptoKit
import SwiftUI

enum EventColor: String, Codable, CaseIterable, Identifiable {
    case teal, blue, orange, purple, pink
    var id: String { rawValue }
    var tint: Color {
        if UserDefaults.standard.string(forKey: "randomnessMode") == "crazy",
           let rgb = UserDefaults.standard.array(forKey: "launchPalette." + rawValue) as? [Double], rgb.count == 3 {
            return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
        }
        return standardTint
    }
    private var standardTint: Color {
        switch self {
        case .teal: .teal
        case .blue: .blue
        case .orange: .orange
        case .purple: .purple
        case .pink: .pink
        }
    }
}

struct CalendarEvent: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool = false
    var location: String = ""
    var notes: String = ""
    var color: EventColor = .teal
    var updatedAt: Date = Date()
    var deletedAt: Date? = nil
    var reminderMinutes: Int? = nil
    var people: [String]? = nil
    var tags: [String]? = nil
    var hostName: String? = nil
    var recurrence: String? = nil
    var recurrenceUntil: Date? = nil
    var seriesID: UUID? = nil
}


enum EventRecurrence {
    static func occurrences(_ event: CalendarEvent, in range: DateInterval) -> [CalendarEvent] {
        guard event.deletedAt == nil else { return [] }
        let calendar = Calendar.current
        let component: Calendar.Component
        switch event.recurrence {
        case "daily": component = .day
        case "weekly": component = .weekOfYear
        case "monthly": component = .month
        default: return event.start < range.end && event.end > range.start ? [event] : []
        }
        let duration = max(0, event.end.timeIntervalSince(event.start))
        let lower = range.start.addingTimeInterval(-duration - 86400)
        let difference = calendar.dateComponents([component], from: event.start, to: lower).value(for: component) ?? 0
        var index = max(0, difference - 2)
        var result: [CalendarEvent] = []
        for _ in 0..<4096 {
            guard let start = calendar.date(byAdding: component, value: index, to: event.start),
                  let end = calendar.date(byAdding: component, value: index, to: event.end), start < range.end else { break }
            if let until = event.recurrenceUntil, calendar.startOfDay(for: start) > calendar.startOfDay(for: until) { break }
            if end > range.start {
                var occurrence = event
                occurrence.start = start
                occurrence.end = end
                occurrence.seriesID = event.id
                if index > 0 {
                    let hash = SHA256.hash(data: Data((event.id.uuidString + ":" + String(index)).utf8))
                    let hex = hash.prefix(16).map { String(format: "%02x", $0) }.joined()
                    let chars = Array(hex)
                    let value = [String(chars[0..<8]), String(chars[8..<12]), String(chars[12..<16]), String(chars[16..<20]), String(chars[20..<32])].joined(separator: "-")
                    occurrence.id = UUID(uuidString: value)!
                }
                result.append(occurrence)
            }
            index += 1
        }
        return result
    }
}
