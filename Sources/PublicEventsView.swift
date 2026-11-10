import SwiftUI

struct PublicHost: Decodable { let displayName: String; let bio: String }
struct PublicListing: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String
    let tags: [String]
    let start: Double
    let end: Double
    let location: String
    let host: PublicHost?
    var published: Bool? = nil
}
private struct ListingPage: Decodable { let page: [PublicListing]; let isDone: Bool; let continueCursor: String }
private struct ConvexResponse: Decodable { let status: String; let value: ListingPage?; let errorMessage: String? }

struct PublicEventsView: View {
    let store: EventStore
    var isTab = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("convexDeploymentURL") private var deploymentURL = "https://majestic-vulture-890.convex.cloud"
    @State private var publish = false
    @State private var hostDashboard = false
    @State private var feedbackEvent: PublicListing?
    @State private var query = ""
    @State private var tag = ""
    @State private var listings: [PublicListing] = []
    @State private var cursor: String?
    @State private var done = true
    @State private var loading = false
    @State private var error: String?
    @State private var draft: CalendarEvent?
    @State private var editor = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Create public event", systemImage: "plus.circle.fill") { publish = true }
                    Button("Read feedback on my events", systemImage: "star.bubble.fill") { hostDashboard = true }
                }
                Section("Find public events") {
                    TextField("Title, host or description", text: $query)
                    TextField("Tag", text: $tag).textInputAutocapitalization(.never)
                    Button(loading ? "Loading…" : "Search public events") { Task { await load(reset: true) } }.disabled(loading)
                }
                if let error { Section { Text(error).foregroundStyle(LaunchAppearance.palette.danger) } }
                ForEach(listings) { listing in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(listing.title).font(.headline)
                            Text(Date(timeIntervalSince1970: listing.start / 1000).formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                            Text(listing.description).font(.subheadline)
                            if let host = listing.host {
                                Label(host.displayName, systemImage: "person.crop.circle").font(.subheadline)
                                if !host.bio.isEmpty { Text(host.bio).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary) }
                            }
                            if !listing.tags.isEmpty { Text(listing.tags.map { "#" + $0 }.joined(separator: " ")).font(.caption).foregroundStyle(.tint) }
                            Button { feedbackEvent = listing } label: {
                                Label("Leave feedback", systemImage: "star.bubble.fill")
                                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 5)
                            }.buttonStyle(.borderedProminent)
                            Button("Add to my calendar", systemImage: "calendar.badge.plus") {
                                draft = CalendarEvent(title: listing.title, start: Date(timeIntervalSince1970: listing.start / 1000), end: Date(timeIntervalSince1970: listing.end / 1000), location: listing.location, notes: listing.description, tags: listing.tags, hostName: listing.host?.displayName)
                                editor = true
                            }
                        }.padding(.vertical, 4)
                    }
                }
                if !done { Button("Load more") { Task { await load(reset: false) } }.disabled(loading) }
                if listings.isEmpty && !loading && error == nil {
                    Text("No public events yet. Create one to get started.").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                }
            }
            .navigationTitle("Discover")
            .toolbar { if !isTab { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } } }
            .task { await load(reset: true) }
            .refreshable { await load(reset: true) }
            .sheet(item: $feedbackEvent) { EventFeedbackView(event: $0) }
            .sheet(isPresented: $hostDashboard) { HostedEventsView(store: store) }
            .sheet(isPresented: $publish, onDismiss: { Task { await load(reset: true) } }) { PublicEventComposer(store: store) }
            .sheet(isPresented: $editor) { EventEditor(store: store, date: Date(), draft: draft) }
        }
    }

    @MainActor private func load(reset: Bool) async {
        let value = deploymentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: value), base.scheme == "https", let host = base.host, host.hasSuffix(".convex.cloud"), base.user == nil, base.password == nil else {
            error = "Enter your HTTPS Convex deployment URL ending in .convex.cloud."
            return
        }
        loading = true
        error = nil
        defer { loading = false }
        if reset { cursor = nil; listings = []; done = true }
        do {
            var args: [String: Any] = ["paginationOpts": ["numItems": 20, "cursor": cursor as Any? ?? NSNull()]]
            if !query.isEmpty { args["text"] = query }
            if !tag.isEmpty { args["tag"] = tag }
            var request = URLRequest(url: base.appendingPathComponent("api/query"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["path": "discovery:search", "args": args, "format": "json"])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                error = "Couldn’t reach this Convex deployment. Check the URL and connection."
                return
            }
            let result = try JSONDecoder().decode(ConvexResponse.self, from: data)
            guard result.status == "success", let page = result.value else {
                error = result.errorMessage ?? "Public discovery is not deployed yet."
                return
            }
            let seen = Set(listings.map(\.id))
            listings += page.page.filter { !seen.contains($0.id) }
            cursor = page.continueCursor
            done = page.isDone
        } catch { self.error = "Couldn’t load listings. \(error.localizedDescription)" }
    }
}

struct PublicDiscoveryPreview: View {
    let store: EventStore
    @State private var listings: [PublicListing] = []
    @State private var loading = true
    @State private var error: String?
    var body: some View {
        Section("Public events · discover without searching") {
            if loading { ProgressView("Loading public events…") }
            ForEach(listings) { event in
                NavigationLink {
                    EventFeedbackView(event: event)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title).font(.headline)
                        Text(Date(timeIntervalSince1970: event.start / 1000).formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                        if let host = event.host { Text("Hosted by " + host.displayName).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary) }
                    }
                }
            }
            if !loading && listings.isEmpty { Text(error ?? "No public events yet. Publish the first one from Discover.").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary) }
            NavigationLink("Browse all public events") { PublicEventsView(store: store) }
        }
        .task {
            do {
                var request = URLRequest(url: ConvexAccount.baseURL.appendingPathComponent("api/query"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["path": "discovery:search", "args": ["paginationOpts": ["numItems": 20, "cursor": NSNull()]], "format": "json"])
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(ConvexResponse.self, from: data)
                listings = response.value?.page ?? []
                if response.status != "success" { error = "Couldn’t load public events. Open Discover to retry." }
            } catch { self.error = "You’re offline. Your private calendar is still available." }
            loading = false
        }
    }
}
