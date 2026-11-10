import SwiftUI

struct PublicEventComposer: View {
    @AppStorage("paletteRevision") private var paletteRevision = 0
    @AppStorage("appearanceTheme") private var activeTheme = "dark"
    let store: EventStore
    @Environment(\.dismiss) private var dismiss
    private var account: ConvexAccount { .shared }
    @State private var username = ""
    @State private var password = ""
    @State private var createAccount = true
    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var tags = ""
    @State private var host = ""
    @State private var bio = ""
    @State private var start = Date().addingTimeInterval(3600)
    @State private var end = Date().addingTimeInterval(7200)
    @State private var localCopy = true
    @State private var busy = false
    @State private var error: String?
    @State private var published = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Your account") {
                    if let name = account.username {
                        Label("Signed in as @" + name, systemImage: "person.crop.circle.fill")
                        Button("Sign out", role: .destructive) { Task { busy = true; await account.signOut(); busy = false } }.disabled(busy)
                    } else {
                        Picker("Account", selection: $createAccount) {
                            Text("Sign up").tag(true)
                            Text("Sign in").tag(false)
                        }.pickerStyle(.segmented)
                        TextField("Username", text: $username).textContentType(.username)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Password (8+ characters)", text: $password)
                            .textContentType(createAccount ? .newPassword : .password)
                        Text("Usernames: 3–30 lowercase letters, numbers or underscores. Password recovery is not available in this prototype.")
                            .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                        Button(createAccount ? "Create account" : "Sign in") {
                            Task {
                                busy = true; error = nil
                                defer { busy = false }
                                do {
                                    try await account.signIn(username: username, password: password, create: createAccount)
                                    password = ""
                                    if host.isEmpty { host = account.username ?? "" }
                                } catch { self.error = error.localizedDescription }
                            }
                        }.disabled(busy || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 8)
                    }
                }.listRowBackground(LaunchAppearance.palette.surface)
                Section("Public event") {
                    TextField("Event title", text: $title)
                    TextField("Description", text: $description, axis: .vertical).lineLimit(3...6)
                    TextField("Location", text: $location)
                    DatePicker("Starts", selection: $start)
                    DatePicker("Ends", selection: $end)
                    if end <= start { Text("End must be after the start.").font(.caption).foregroundStyle(LaunchAppearance.palette.danger) }
                    TextField("Tags, separated by commas", text: $tags).textInputAutocapitalization(.never)
                }.listRowBackground(LaunchAppearance.palette.surface)
                Section("Host profile") {
                    TextField("Public host name", text: $host)
                    TextField("About the host", text: $bio, axis: .vertical)
                }.listRowBackground(LaunchAppearance.palette.surface)
                Section {
                    Toggle("Also add to my private calendar", isOn: $localCopy)
                    Text("Publishing makes this event and host profile visible to everyone. Your other calendar events stay private.")
                        .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                    Button(busy ? "Please wait…" : "Publish public event", systemImage: "globe") {
                        Task { await publish() }
                    }.disabled(busy || account.username == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || end <= start)
                }.listRowBackground(LaunchAppearance.palette.surface)
                if let error { Section { Text(error).foregroundStyle(LaunchAppearance.palette.danger).textSelection(.enabled) }.listRowBackground(LaunchAppearance.palette.surface) }
            }
            .calendarTheme()
            .navigationTitle("Create public event")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .alert("Event published", isPresented: $published) {
                Button("Done") { dismiss() }
            } message: { Text("Your event is now available in public discovery.") }
            .onAppear { if host.isEmpty { host = account.username ?? "" } }
        }
    }

    @MainActor private func publish() async {
        busy = true; error = nil
        defer { busy = false }
        let cleanTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#")) }.filter { !$0.isEmpty }
        do {
            try await account.publish(title: title, description: description, start: start, end: end, location: location, tags: cleanTags, host: host, bio: bio)
            if localCopy { store.upsert(CalendarEvent(title: title, start: start, end: end, location: location, notes: description, tags: cleanTags, hostName: host)) }
            published = true
        } catch { self.error = error.localizedDescription }
    }
}
