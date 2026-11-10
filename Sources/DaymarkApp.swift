import SwiftUI

@main
struct DaymarkApp: App {
    @State private var store = EventStore()
    var body: some Scene {
        WindowGroup {
            CalendarView(store: store)
                .preferredColorScheme(.dark)
                .tint(.red)
        }
    }
}
