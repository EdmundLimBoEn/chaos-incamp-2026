import Foundation

let calendar = Calendar.current
let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 10))!
let query = EventSearchQuery(raw: "design tomorrow at 3:30pm @Alex #work", now: now)
let draft = query.draft()
assert(draft.title == "design")
assert(calendar.component(.day, from: draft.start) == 11)
assert(calendar.component(.hour, from: draft.start) == 15)
assert(calendar.component(.minute, from: draft.start) == 30)
assert(draft.people == ["Alex"] && draft.tags == ["work"])
assert(query.matches(draft))
var wrongPerson = draft
wrongPerson.people = ["Sam"]
assert(!query.matches(wrongPerson))
assert(!EventSearchQuery(raw: "today", now: now).matches(draft))
assert(EventSearchQuery(raw: "Alex", now: now).matches(draft))
var oldJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as! [String: Any]
for key in ["people", "tags", "hostName", "reminderMinutes"] { oldJSON.removeValue(forKey: key) }
let legacy = try JSONDecoder().decode(CalendarEvent.self, from: JSONSerialization.data(withJSONObject: oldJSON))
assert(legacy.title == draft.title && legacy.people == nil && legacy.tags == nil)
print("Search parsing, matching, draft creation and legacy event decoding passed")
let natural = EventSearchQuery(raw: "lunch with john 3pm 10 november 2026", now: now).draft()
assert(natural.title.lowercased() == "lunch")
assert(natural.people?.map { $0.lowercased() } == ["john"])
assert(calendar.component(.day, from: natural.start) == 10)
assert(calendar.component(.month, from: natural.start) == 11)
assert(calendar.component(.year, from: natural.start) == 2026)
assert(calendar.component(.hour, from: natural.start) == 15)
print("Natural-language screenshot regression passed")
var weekly = CalendarEvent(title: "Weekly standup", start: now, end: now.addingTimeInterval(3600), recurrence: "weekly")
let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)!
let nextRange = calendar.dateInterval(of: .day, for: nextWeek)!
let occurrences = EventRecurrence.occurrences(weekly, in: nextRange)
assert(occurrences.count == 1 && occurrences[0].start == nextWeek)
assert(occurrences[0].seriesID == weekly.id && occurrences[0].id != weekly.id)
assert(EventRecurrence.occurrences(weekly, in: nextRange)[0].id == occurrences[0].id)
weekly.recurrenceUntil = now
assert(EventRecurrence.occurrences(weekly, in: nextRange).isEmpty)
let jan = calendar.date(from: DateComponents(year: 2027, month: 1, day: 31, hour: 9))!
let monthly = CalendarEvent(title: "Month end", start: jan, end: jan.addingTimeInterval(3600), recurrence: "monthly")
let march = calendar.date(from: DateComponents(year: 2027, month: 3, day: 31))!
let marchResult = EventRecurrence.occurrences(monthly, in: calendar.dateInterval(of: .day, for: march)!)
assert(marchResult.count == 1 && calendar.component(.day, from: marchResult[0].start) == 31)
print("Recurring events: weekly dates, stable IDs, end date and month anchor passed")
