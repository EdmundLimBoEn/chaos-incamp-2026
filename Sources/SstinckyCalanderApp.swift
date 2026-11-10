import SwiftUI

@main
struct SstinckyCalanderApp: App {
    @State private var store = EventStore()
    var body: some Scene {
        WindowGroup {
            CalendarView(store: store)
                .preferredColorScheme(.dark)
                .tint(.red)
        }
    }
}
