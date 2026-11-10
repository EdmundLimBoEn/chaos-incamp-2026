import Foundation

struct EventSearchQuery {
    let text: String
    let interval: DateInterval?
    let hour: Int?
    let people: [String]
    let tags: [String]
    private let minute: Int
    private let now: Date

    init(raw: String, now: Date = Date()) {
        self.now = now
        let calendar = Calendar.current
        var remaining = raw
        var foundPeople: [String] = []
        var foundTags: [String] = []
        func extract(_ pattern: String, from source: inout String) -> [[String]] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
            let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
            let values = matches.map { match in
                (0..<match.numberOfRanges).map { index in
                    Range(match.range(at: index), in: source).map { String(source[$0]) } ?? ""
                }
            }
            source = regex.stringByReplacingMatches(in: source, range: NSRange(source.startIndex..., in: source), withTemplate: " ")
            return values
        }
        foundPeople = extract(#"(?:^|\s)@([\p{L}\p{N}_-]+)"#, from: &remaining).map { $0[1] }
        foundTags = extract(#"(?:^|\s)#([\p{L}\p{N}_-]+)"#, from: &remaining).map { $0[1] }
        people = foundPeople
        tags = foundTags

        var dateRange: DateInterval?
        let today = calendar.startOfDay(for: now)
        func dayRange(_ date: Date) -> DateInterval? { calendar.dateInterval(of: .day, for: date) }
        if !extract(#"\btomorrow\b"#, from: &remaining).isEmpty {
            dateRange = calendar.date(byAdding: .day, value: 1, to: today).flatMap(dayRange)
        } else if !extract(#"\btoday\b"#, from: &remaining).isEmpty {
            dateRange = dayRange(today)
        } else if !extract(#"\bthis\s+week\b"#, from: &remaining).isEmpty {
            dateRange = calendar.dateInterval(of: .weekOfYear, for: now)
        } else {
            let isoPattern = #"\b\d{4}-\d{2}-\d{2}\b"#
            if let regex = try? NSRegularExpression(pattern: isoPattern),
               let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)),
               let range = Range(match.range, in: remaining) {
                let token = String(remaining[range])
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.calendar = calendar
                formatter.timeZone = calendar.timeZone
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.isLenient = false
                if let date = formatter.date(from: token), formatter.string(from: date) == token {
                    dateRange = dayRange(date)
                    remaining.replaceSubrange(range, with: " ")
                }
            }
            if dateRange == nil {
                let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
                for (index, name) in weekdays.enumerated() {
                    if !extract("\\b(?:next\\s+)?" + name + "\\b", from: &remaining).isEmpty {
                        let delta = (index + 1 - calendar.component(.weekday, from: today) + 7) % 7
                        let offset = raw.localizedCaseInsensitiveContains("next " + name) && delta == 0 ? 7 : delta
                        dateRange = calendar.date(byAdding: .day, value: offset, to: today).flatMap(dayRange)
                        break
                    }
                }
            }
        }
        interval = dateRange

        var foundHour: Int?
        var foundMinute = 0
        // Requiring a meridiem or colon keeps ordinary numbers in event titles searchable.
        let timePattern = #"\b(?:at\s+)?(\d{1,2})(?::([0-5]\d))?\s*(am|pm)\b|\b(?:at\s+)?([01]?\d|2[0-3]):([0-5]\d)\b"#
        if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)),
           let range = Range(match.range, in: remaining) {
            func capture(_ index: Int) -> String {
                Range(match.range(at: index), in: remaining).map { String(remaining[$0]) } ?? ""
            }
            if let number = Int(capture(1)), (1...12).contains(number) {
                foundHour = number % 12 + (capture(3).lowercased() == "pm" ? 12 : 0)
                foundMinute = Int(capture(2)) ?? 0
            } else if let number = Int(capture(4)) {
                foundHour = number
                foundMinute = Int(capture(5)) ?? 0
            }
            if foundHour != nil { remaining.replaceSubrange(range, with: " ") }
        }
        hour = foundHour
        minute = foundMinute
        text = remaining.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func matches(_ event: CalendarEvent) -> Bool {
        guard event.deletedAt == nil else { return false }
        if let interval, !(event.start < interval.end && event.end > interval.start) { return false }
        if let hour, Calendar.current.component(.hour, from: event.start) != hour { return false }
        let eventPeople = (event.people ?? []) + [event.hostName ?? ""]
        if !people.allSatisfy({ term in eventPeople.contains { $0.localizedCaseInsensitiveContains(term) } }) { return false }
        if !tags.allSatisfy({ term in (event.tags ?? []).contains { $0.localizedCaseInsensitiveCompare(term) == .orderedSame } }) { return false }
        let searchable = ([event.title, event.location, event.notes] + eventPeople + (event.tags ?? [])).joined(separator: " ")
        return text.split(whereSeparator: \.isWhitespace).allSatisfy { searchable.localizedCaseInsensitiveContains(String($0)) }
    }

    func draft() -> CalendarEvent {
        let calendar = Calendar.current
        let base = interval?.start ?? now
        let start: Date
        if let hour {
            let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
            start = interval == nil && time <= now ? (calendar.date(byAdding: .day, value: 1, to: time) ?? time) : time
        } else if interval != nil {
            start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
        } else {
            let nextHour = now.addingTimeInterval(3600)
            start = calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
        }
        var event = CalendarEvent(title: text.isEmpty ? "New event" : text, start: start, end: start.addingTimeInterval(3600))
        event.people = people.isEmpty ? nil : people
        event.tags = tags.isEmpty ? nil : tags
        return event
    }

    var querySummary: String {
        var parts: [String] = []
        if let interval {
            if interval.duration > 90000 {
                parts.append(interval.start.formatted(date: .abbreviated, time: .omitted) + " – " + interval.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))
            } else {
                parts.append(interval.start.formatted(date: .abbreviated, time: .omitted))
            }
        }
        if let hour { parts.append(String(format: "%02d:%02d", hour, minute)) }
        parts += people.map { "@" + $0 }
        parts += tags.map { "#" + $0 }
        return parts.joined(separator: " · ")
    }
}
