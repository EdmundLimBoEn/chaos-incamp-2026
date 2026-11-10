import SwiftUI

private struct FeedbackConfirmation: Decodable { let confirmation: String }
private struct HostEvents: Decodable { let events: [PublicListing] }
private struct HostReport: Decodable {
    struct Item: Decodable, Identifiable { let id: String; let rating: Int; let message: String; let updatedAt: Double; let authorName: String }
    let title: String
    let feedback: [Item]
    let averageRating: Double?
    let count: Int
}

struct AccountLoginSection: View {
    @State private var username = ""
    @State private var password = ""
    @State private var create = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        Section("Account") {
            if let name = ConvexAccount.shared.username { Label("Signed in as @" + name, systemImage: "person.crop.circle") }
            else {
                Picker("Account", selection: $create) { Text("Sign in").tag(false); Text("Sign up").tag(true) }.pickerStyle(.segmented)
                TextField("Username", text: $username).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Password", text: $password).textContentType(create ? .newPassword : .password)
                Button(create ? "Create account" : "Sign in") {
                    Task {
                        busy = true; error = nil
                        defer { busy = false }
                        do { try await ConvexAccount.shared.signIn(username: username, password: password, create: create); password = "" }
                        catch { self.error = error.localizedDescription }
                    }
                }.disabled(busy || username.isEmpty || password.count < 8)
                if let error { Text(error).font(.caption).foregroundStyle(LaunchAppearance.palette.danger) }
            }
        }
    }
}

struct EventFeedbackView: View {
    let event: PublicListing
    @Environment(\.dismiss) private var dismiss
    @State private var rating = 5
    @State private var message = ""
    @State private var busy = false
    @State private var error: String?
    @State private var submitted = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(event.title).font(.title2.bold())
                    Text("How was this event?").font(.headline)
                    if let host = event.host { Text("Your feedback goes to " + host.displayName).font(.subheadline).foregroundStyle(.secondary) }
                }
                AccountLoginSection()
                Section("Your rating") {
                    HStack {
                        ForEach(1...5, id: \.self) { value in
                            Button { rating = value } label: { Image(systemName: value <= rating ? "star.fill" : "star").font(.title).foregroundStyle(LaunchAppearance.color("orange", fallback: .orange)) }
                                .buttonStyle(.plain).accessibilityLabel("\(value) stars")
                        }
                    }
                    Text("\(rating) out of 5 stars").font(.subheadline.bold())
                    TextField("What should the host know?", text: $message, axis: .vertical).lineLimit(4...8)
                    Text("Your rating and message are shared with the event host. Sending again updates your previous feedback.").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                    Button(busy ? "Sending…" : "Submit feedback") {
                        Task {
                            busy = true; error = nil
                            defer { busy = false }
                            do {
                                _ = try await ConvexAccount.shared.authenticated(FeedbackConfirmation.self, kind: "mutation", path: "feedback:submit", args: ["listingId": event.id, "rating": rating, "message": message])
                                submitted = true
                            } catch { self.error = error.localizedDescription }
                        }
                    }.buttonStyle(.borderedProminent)
                        .disabled(busy || ConvexAccount.shared.username == nil || message.count > 3000)
                    if ConvexAccount.shared.username == nil { Text("Sign in above to send your feedback.").font(.caption).foregroundStyle(.secondary) }
                }
                if let error { Section { Text(error).foregroundStyle(LaunchAppearance.palette.danger) } }
            }
            .navigationTitle("Event feedback")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .alert("Feedback submitted", isPresented: $submitted) { Button("Done") { dismiss() } } message: { Text("Thanks! The event host can now read your feedback.") }
        }
    }
}

struct HostedEventsView: View {
    var store: EventStore? = nil
    var isTab = false
    @State private var browse = false
    @Environment(\.dismiss) private var dismiss
    @State private var events: [PublicListing] = []
    @State private var selected: PublicListing?
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Event feedback", systemImage: "star.bubble.fill").font(.title2.bold())
                    Text("Rate an event you attended, or read what people sent about events you host.")
                        .foregroundStyle(.secondary)
                    if store != nil {
                        Button { browse = true } label: {
                            Label("Leave feedback on an event", systemImage: "square.and.pencil")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                        }.buttonStyle(.borderedProminent)
                    }
                }
                if ConvexAccount.shared.username == nil {
                    Section { Text("Sign in below to see feedback on your hosted events.").font(.subheadline) }
                }
                AccountLoginSection()
                Section("Received · events you host") {
                    Text("Tap an event below to read its ratings and messages.").font(.caption).foregroundStyle(.secondary)
                }
                if loading { ProgressView() }
                if let error { Text(error).foregroundStyle(LaunchAppearance.palette.danger) }
                ForEach(events) { event in
                    Button { selected = event } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.headline)
                            Text(event.published == false ? "Unpublished · View feedback" : "View ratings & feedback").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                        }
                    }
                }
                if events.isEmpty && !loading && ConvexAccount.shared.username != nil { Text("No hosted events yet. Publish a public event from Discover to start receiving feedback.").foregroundStyle(LaunchAppearance.palette.secondary) }
            }
            .navigationTitle("Feedback")
            .toolbar { if !isTab { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } }
            .sheet(isPresented: $browse) { if let store { PublicEventsView(store: store) } }
            .task(id: ConvexAccount.shared.username) { await load() }
            .refreshable { await load() }
            .sheet(item: $selected) { HostFeedbackView(event: $0) }
        }
    }
    private func load() async {
        guard ConvexAccount.shared.username != nil else { events = []; return }
        loading = true; error = nil
        defer { loading = false }
        do { events = try await ConvexAccount.shared.authenticated(HostEvents.self, kind: "query", path: "discovery:myListings", args: [:]).events }
        catch { self.error = error.localizedDescription }
    }
}

private struct HostFeedbackView: View {
    let event: PublicListing
    @Environment(\.dismiss) private var dismiss
    @State private var report: HostReport?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                if let report {
                    Section(event.title) {
                        Text("\(report.count) ratings · \(report.averageRating ?? 0, specifier: "%.1f") / 5")
                    }
                    ForEach(report.feedback) { feedback in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(repeating: "★", count: feedback.rating)).foregroundStyle(LaunchAppearance.color("orange", fallback: .orange))
                            Text(feedback.authorName).font(.headline)
                            Text(feedback.message.isEmpty ? "No written feedback" : feedback.message)
                            Text(Date(timeIntervalSince1970: feedback.updatedAt / 1000).formatted()).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                        }
                    }
                    if report.feedback.isEmpty { Text("No feedback yet.").foregroundStyle(LaunchAppearance.palette.secondary) }
                } else if let error { Text(error).foregroundStyle(LaunchAppearance.palette.danger) }
                else { ProgressView() }
            }
            .navigationTitle("Ratings & feedback")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                do { report = try await ConvexAccount.shared.authenticated(HostReport.self, kind: "query", path: "feedback:forHost", args: ["listingId": event.id]) }
                catch { self.error = error.localizedDescription }
            }
        }
    }
}
