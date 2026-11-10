import SwiftUI

@main
struct SstinckyCalanderApp: App {
    @AppStorage("appearanceTheme") private var theme = "dark"
    @AppStorage("accentColor") private var accent = "red"
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("paletteRevision") private var revision = 0
    @State private var launchID = UUID()
    @State private var wasBackgrounded = true
    @State private var store = EventStore()
    var body: some Scene {
        WindowGroup {
            TabView {
                CalendarView(store: store)
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                PublicEventsView(store: store, isTab: true)
                    .tabItem { Label("Discover", systemImage: "globe") }
                HostedEventsView(store: store, isTab: true)
                    .tabItem { Label("Feedback", systemImage: "star.bubble.fill") }
            }
                .overlay { LaunchEffectsView().id(launchID) }
                .foregroundStyle(LaunchAppearance.palette.foreground)
                .background(LaunchAppearance.palette.background)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .background { wasBackgrounded = true }
                    if phase == .active && wasBackgrounded {
                        wasBackgrounded = false
                        LaunchAppearance.refreshForLaunch()
                        launchID = UUID()
                    }
                }
                .preferredColorScheme(CalendarAppearance.scheme(theme))
                .tint(CalendarAppearance.accent(accent))
                .task { ReminderScheduler.shared.configure(); store.refreshReminders() }
        }
    }
}
