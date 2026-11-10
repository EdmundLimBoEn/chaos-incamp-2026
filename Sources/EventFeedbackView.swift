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
    @AppStorage("paletteRevision") private var paletteRevision = 0
    @AppStorage("appearanceTheme") private var activeTheme = "dark"
    @State private var username = ""
    @State private var password = ""
    @State private var create = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        Section("Account") {
            if let name = ConvexAccount.shared.username { Text("@" + name).foregroundStyle(LaunchAppearance.palette.secondary) }
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
        }.listRowBackground(LaunchAppearance.palette.surface)
    }
}

struct EventFeedbackView: View {
    @AppStorage("paletteRevision") private var paletteRevision = 0
    @AppStorage("appearanceTheme") private var activeTheme = "dark"
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
                    Text(event.title).font(.headline)
                    if let host = event.host { Text(host.displayName).font(.subheadline).foregroundStyle(LaunchAppearance.palette.secondary) }
                }.listRowBackground(LaunchAppearance.palette.surface)
                if ConvexAccount.shared.username == nil { AccountLoginSection() }
                Section("Rating") {
                    HStack {
                        ForEach(1...5, id: \.self) { value in
                            Button { rating = value } label: { Image(systemName: value <= rating ? "star.fill" : "star").font(.title2).foregroundStyle(LaunchAppearance.color("orange", fallback: .orange)).frame(minWidth: 44, minHeight: 44) }
                                .buttonStyle(.plain).accessibilityLabel("\(value) stars")
                        }.listRowBackground(LaunchAppearance.palette.surface)
                    }
                    Text("\(rating) / 5").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                    TextField("Comment (optional)", text: $message, axis: .vertical).lineLimit(3...6)
                    Text("Shared with the host.").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                    Button(busy ? "Sending…" : "Send feedback") {
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
                    if ConvexAccount.shared.username == nil { Text("Sign in to send.").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary) }
                }.listRowBackground(LaunchAppearance.palette.surface)
                if let error { Section { Text(error).foregroundStyle(LaunchAppearance.palette.danger) }.listRowBackground(LaunchAppearance.palette.surface) }
            }
            .calendarTheme()
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .alert("Feedback submitted", isPresented: $submitted) { Button("Done") { dismiss() } } message: { Text("Sent to the host.") }
        }
    }
}

struct HostedEventsView: View {
    @AppStorage("paletteRevision") private var paletteRevision = 0
    @AppStorage("appearanceTheme") private var activeTheme = "dark"
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
                if store != nil {
                    Section {
                        Button("Leave feedback") { browse = true }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.bordered)
                    }.listRowBackground(LaunchAppearance.palette.surface)
                }
                if ConvexAccount.shared.username == nil { AccountLoginSection() }
                if loading { ProgressView() }
                if let error { Text(error).foregroundStyle(LaunchAppearance.palette.danger) }
                if ConvexAccount.shared.username != nil {
                    Section("Your events") {
                        ForEach(events) { event in
                            Button { selected = event } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title).font(.headline)
                                    Text(event.published == false ? "Unpublished" : Date(timeIntervalSince1970: event.start / 1000).formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                                }
                            }
                        }
                        if events.isEmpty && !loading {
                            Text("No hosted events yet.").foregroundStyle(LaunchAppearance.palette.secondary)
                        }
                    }.listRowBackground(LaunchAppearance.palette.surface)
                }
            }
            .calendarTheme()
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
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
    @AppStorage("paletteRevision") private var paletteRevision = 0
    @AppStorage("appearanceTheme") private var activeTheme = "dark"
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
                    }.listRowBackground(LaunchAppearance.palette.surface)
                    ForEach(report.feedback) { feedback in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(repeating: "★", count: feedback.rating)).foregroundStyle(LaunchAppearance.color("orange", fallback: .orange))
                            Text(feedback.authorName).font(.headline)
                            if !feedback.message.isEmpty { Text(feedback.message) }
                            Text(Date(timeIntervalSince1970: feedback.updatedAt / 1000).formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                        }
                    }.listRowBackground(LaunchAppearance.palette.surface)
                    if report.feedback.isEmpty { Text("No feedback yet.").foregroundStyle(LaunchAppearance.palette.secondary) }
                } else if let error { Text(error).foregroundStyle(LaunchAppearance.palette.danger) }
                else { ProgressView() }
            }
            .calendarTheme()
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                do { report = try await ConvexAccount.shared.authenticated(HostReport.self, kind: "query", path: "feedback:forHost", args: ["listingId": event.id]) }
                catch { self.error = error.localizedDescription }
            }
        }
    }
}
