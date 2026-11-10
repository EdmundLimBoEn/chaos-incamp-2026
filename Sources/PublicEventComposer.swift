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
                Section("Account") {
                    if let name = account.username {
                        Text("@" + name).foregroundStyle(LaunchAppearance.palette.secondary)
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
                        if createAccount {
                            Text("3–30 letters, numbers or underscores. No password reset.")
                                .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                        }
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
                Section {
                    TextField("Event title", text: $title)
                    TextField("Host name", text: $host)
                }.listRowBackground(LaunchAppearance.palette.surface)
                Section("When") {
                    DatePicker("Starts", selection: $start)
                    DatePicker("Ends", selection: $end)
                    if end <= start { Text("End must be after the start.").font(.caption).foregroundStyle(LaunchAppearance.palette.danger) }
                }.listRowBackground(LaunchAppearance.palette.surface)
                Section {
                    DisclosureGroup("More details") {
                        TextField("Description", text: $description, axis: .vertical).lineLimit(3...6)
                        TextField("Location", text: $location)
                        TextField("Tags, separated by commas", text: $tags).textInputAutocapitalization(.never)
                        TextField("Host bio", text: $bio, axis: .vertical).lineLimit(2...4)
                    }
                }.listRowBackground(LaunchAppearance.palette.surface)
                Section {
                    Toggle("Add to my calendar", isOn: $localCopy)
                    Text("This event will be public.")
                        .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                    Button(busy ? "Publishing…" : "Publish event") {
                        Task { await publish() }
                    }.buttonStyle(.borderedProminent)
                        .disabled(busy || account.username == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || end <= start)
                }.listRowBackground(LaunchAppearance.palette.surface)
                if let error { Section { Text(error).foregroundStyle(LaunchAppearance.palette.danger).textSelection(.enabled) }.listRowBackground(LaunchAppearance.palette.surface) }
            }
            .calendarTheme()
            .navigationTitle("Public event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .alert("Event published", isPresented: $published) {
                Button("Done") { dismiss() }
            } message: { Text("Your event is live in Discover.") }
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
