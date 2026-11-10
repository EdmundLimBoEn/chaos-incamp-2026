import Foundation
import SwiftUI

enum EventColor: String, Codable, CaseIterable, Identifiable {
    case teal, blue, orange, purple, pink
    var id: String { rawValue }
    var tint: Color {
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
}
