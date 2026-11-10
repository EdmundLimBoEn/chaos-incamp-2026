import SwiftUI

@main
struct SstinckyCalanderApp: App {
    @AppStorage("appearanceTheme") private var theme = "dark"
    @AppStorage("accentColor") private var accent = "red"
    @State private var store = EventStore()
    var body: some Scene {
        WindowGroup {
            CalendarView(store: store)
                .preferredColorScheme(CalendarAppearance.scheme(theme))
                .tint(CalendarAppearance.accent(accent))
                .task { ReminderScheduler.shared.configure(); store.refreshReminders() }
        }
    }
}
