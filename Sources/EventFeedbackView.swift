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
        VStack(alignment: .leading, spacing: 4) {
            if let name = ConvexAccount.shared.username {
                Text("@" + name).foregroundStyle(LaunchAppearance.palette.secondary)
            } else {
                Picker("Account", selection: $create) {
                    Text("Sign in").tag(false)
                    Text("Sign up").tag(true)
                }.pickerStyle(.segmented).frame(minHeight: 44)
                TextField("Username", text: $username)
                    .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .frame(minHeight: 44)
                Divider()
                SecureField("Password (8+ characters)", text: $password)
                    .textContentType(create ? .newPassword : .password).frame(minHeight: 44)
                Divider()
                Button(busy ? "Signing in…" : create ? "Create account" : "Sign in") {
                    Task {
                        busy = true; error = nil
                        defer { busy = false }
                        do { try await ConvexAccount.shared.signIn(username: username, password: password, create: create); password = "" }
                        catch { self.error = error.localizedDescription }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.borderless)
                .disabled(busy || username.isEmpty || password.count < 8)
                if let error { Text(error).font(.caption).foregroundStyle(LaunchAppearance.palette.danger) }
            }
        }.feedbackCard()
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
            List {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.headline)
                    if let host = event.host {
                        Text(host.displayName).font(.subheadline).foregroundStyle(LaunchAppearance.palette.secondary)
                    }
                }.feedbackCard()
                if ConvexAccount.shared.username == nil { AccountLoginSection() }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { value in
                            Button { rating = value } label: {
                                Image(systemName: value <= rating ? "star.fill" : "star")
                                    .font(.title2).foregroundStyle(LaunchAppearance.color("orange", fallback: .orange))
                                    .frame(minWidth: 44, minHeight: 44)
                            }.buttonStyle(.plain).accessibilityLabel("\(value) stars")
                                .accessibilityAddTraits(value == rating ? [.isSelected] : [])
                        }
                        Spacer(minLength: 0)
                    }.accessibilityElement(children: .contain).accessibilityLabel("Rating, \(rating) out of 5")
                    Divider()
                    TextField("Comment (optional)", text: $message, axis: .vertical)
                        .lineLimit(2...6).frame(minHeight: 72, alignment: .top)
                    Text("Shared with the host.").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                    Button {
                        Task {
                            busy = true; error = nil
                            defer { busy = false }
                            do {
                                _ = try await ConvexAccount.shared.authenticated(FeedbackConfirmation.self, kind: "mutation", path: "feedback:submit", args: ["listingId": event.id, "rating": rating, "message": message])
                                submitted = true
                            } catch { self.error = error.localizedDescription }
                        }
                    } label: {
                        Text(busy ? "Sending…" : "Send feedback").frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.borderedProminent)
                        .disabled(busy || ConvexAccount.shared.username == nil || message.count > 3000)
                    if ConvexAccount.shared.username == nil {
                        Text("Sign in to send.").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                    }
                    if let error { Text(error).font(.subheadline).foregroundStyle(LaunchAppearance.palette.danger) }
                }.feedbackCard()
            }
            .listStyle(.plain)
            .contentMargins(.vertical, 0, for: .scrollContent)
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
                if ConvexAccount.shared.username == nil { AccountLoginSection() }
                if loading { ProgressView().frame(maxWidth: .infinity, minHeight: 44).feedbackClearRow() }
                if let error { Text(error).foregroundStyle(LaunchAppearance.palette.danger).feedbackCard() }
                if ConvexAccount.shared.username != nil {
                    if !events.isEmpty {
                        Text("Your events").font(.subheadline.weight(.semibold))
                            .foregroundStyle(LaunchAppearance.palette.secondary).feedbackClearRow()
                    }
                    ForEach(events) { event in
                        Button { selected = event } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title).font(.headline).foregroundStyle(LaunchAppearance.palette.foreground)
                                    Text(event.published == false ? "Unpublished" : Date(timeIntervalSince1970: event.start / 1000).formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                    .foregroundStyle(LaunchAppearance.palette.secondary).accessibilityHidden(true)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).feedbackCard()
                    }
                    if events.isEmpty && !loading {
                        Text("No hosted events yet.").foregroundStyle(LaunchAppearance.palette.secondary).feedbackCard()
                    }
                }
            }
            .listStyle(.plain)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .calendarTheme()
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isTab { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                if store != nil { ToolbarItem(placement: .topBarTrailing) { Button("Leave feedback") { browse = true } } }
            }
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title).font(.headline)
                        Text("\(report.count) ratings · \(report.averageRating ?? 0, specifier: "%.1f") / 5")
                            .font(.subheadline).foregroundStyle(LaunchAppearance.palette.secondary)
                    }.feedbackCard()
                    ForEach(report.feedback) { feedback in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(feedback.authorName).font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Text(String(repeating: "★", count: feedback.rating))
                                    .font(.caption).foregroundStyle(LaunchAppearance.color("orange", fallback: .orange))
                                    .accessibilityLabel("\(feedback.rating) out of 5 stars")
                                Text(Date(timeIntervalSince1970: feedback.updatedAt / 1000).formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                            }
                            if !feedback.message.isEmpty { Text(feedback.message).fixedSize(horizontal: false, vertical: true) }
                        }.feedbackCard()
                    }
                    if report.feedback.isEmpty { Text("No feedback yet.").foregroundStyle(LaunchAppearance.palette.secondary).feedbackCard() }
                } else if let error { Text(error).foregroundStyle(LaunchAppearance.palette.danger).feedbackCard() }
                else { ProgressView().frame(maxWidth: .infinity, minHeight: 44).feedbackClearRow() }
            }
            .listStyle(.plain)
            .contentMargins(.vertical, 0, for: .scrollContent)
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

private extension View {
    func feedbackCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(LaunchAppearance.palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .feedbackClearRow()
    }

    func feedbackClearRow() -> some View {
        listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
