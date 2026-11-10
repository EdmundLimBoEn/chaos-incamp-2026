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
    var calendarDraft: CalendarEvent {
        CalendarEvent(title: title, start: Date(timeIntervalSince1970: start / 1000), end: Date(timeIntervalSince1970: end / 1000), location: location, notes: description, tags: tags, hostName: host?.displayName)
    }
}
private struct ListingPage: Decodable { let page: [PublicListing]; let isDone: Bool; let continueCursor: String }
private struct ConvexResponse: Decodable { let status: String; let value: ListingPage?; let errorMessage: String? }

struct PublicEventsView: View {
    @AppStorage("paletteRevision") private var paletteRevision = 0
    @AppStorage("appearanceTheme") private var activeTheme = "dark"
    let store: EventStore
    var isTab = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("convexDeploymentURL") private var deploymentURL = "https://majestic-vulture-890.convex.cloud"
    @State private var publish = false
    @State private var feedbackEvent: PublicListing?
    @State private var query = ""
    @State private var tag = ""
    @State private var availableTags: [String] = []
    @State private var requestID = UUID()
    @State private var listings: [PublicListing] = []
    @State private var cursor: String?
    @State private var done = true
    @State private var loading = false
    @State private var error: String?
    @State private var importEvent: PublicListing?

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Section { Text(error).foregroundStyle(LaunchAppearance.palette.danger) }
                        .listRowBackground(LaunchAppearance.palette.surface)
                }
                if loading && listings.isEmpty { ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear) }
                ForEach(listings) { listing in
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Button { importEvent = listing } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(listing.title).font(.headline).foregroundStyle(LaunchAppearance.palette.foreground)
                                    Text(Date(timeIntervalSince1970: listing.start / 1000).formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline).foregroundStyle(LaunchAppearance.palette.secondary)
                                    if let host = listing.host {
                                        Text(host.displayName).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                                    }
                                    if !listing.description.isEmpty {
                                        Text(listing.description).font(.subheadline).foregroundStyle(LaunchAppearance.palette.foreground).lineLimit(2)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            if !listing.tags.isEmpty {
                                Text(listing.tags.prefix(3).map { "#" + $0 }.joined(separator: "  "))
                                    .font(.caption).foregroundStyle(LaunchAppearance.palette.secondary).lineLimit(1)
                            }
                            HStack(spacing: 16) {
                                Button("Add to calendar") { importEvent = listing }
                                    .buttonStyle(.bordered).frame(minHeight: 44)
                                Button("Feedback") { feedbackEvent = listing }
                                    .buttonStyle(.borderless).frame(minHeight: 44)
                            }
                        }.padding(.vertical, 2)
                    }.listRowBackground(LaunchAppearance.palette.surface)
                }
                if !done { Button("Load more") { Task { await load(reset: false) } }.disabled(loading) }
                if listings.isEmpty && !loading && error == nil {
                    ContentUnavailableView(query.isEmpty && tag.isEmpty ? "No events yet" : "No matches", systemImage: "calendar")
                        .listRowBackground(Color.clear)
                }
            }
            .calendarTheme()
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search events")
            .toolbar {
                if !isTab { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !availableTags.isEmpty {
                        Menu {
                            Picker("Tag", selection: $tag) {
                                Text("All tags").tag("")
                                ForEach(availableTags, id: \.self) { Text($0).tag($0) }
                            }
                        } label: {
                            Image(systemName: tag.isEmpty ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                        }.accessibilityLabel("Filter by tag")
                    }
                    Button("Create event", systemImage: "plus") { publish = true }
                }
            }
            .task(id: query + "|" + tag) {
                if !query.isEmpty { try? await Task.sleep(for: .milliseconds(350)) }
                guard !Task.isCancelled else { return }
                await load(reset: true)
            }
            .refreshable { await load(reset: true) }
            .sheet(item: $feedbackEvent) { EventFeedbackView(event: $0) }
            .sheet(isPresented: $publish, onDismiss: { Task { await load(reset: true) } }) { PublicEventComposer(store: store) }
            .sheet(item: $importEvent) { listing in
                EventEditor(store: store, date: Date(timeIntervalSince1970: listing.start / 1000), draft: listing.calendarDraft)
                    .id(listing.id)
            }
        }
    }

    @MainActor private func load(reset: Bool) async {
        let value = deploymentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: value), base.scheme == "https", let host = base.host, host.hasSuffix(".convex.cloud"), base.user == nil, base.password == nil else {
            error = "Enter your HTTPS Convex deployment URL ending in .convex.cloud."
            return
        }
        let currentRequest = UUID()
        requestID = currentRequest
        loading = true
        error = nil
        defer { if requestID == currentRequest { loading = false } }
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
            guard !Task.isCancelled, requestID == currentRequest else { return }
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
            availableTags = Array(Set(availableTags + page.page.flatMap(\.tags))).sorted()
        } catch {
            guard !Task.isCancelled, requestID == currentRequest else { return }
            self.error = "Couldn’t load events. Pull down to retry."
        }
    }
}

struct PublicDiscoveryPreview: View {
    @AppStorage("paletteRevision") private var paletteRevision = 0
    @AppStorage("appearanceTheme") private var activeTheme = "dark"
    let store: EventStore
    @State private var importEvent: PublicListing?
    @State private var feedbackEvent: PublicListing?
    @State private var listings: [PublicListing] = []
    @State private var loading = true
    @State private var error: String?
    var body: some View {
        Section("Discover") {
            if loading { ProgressView() }
            ForEach(listings) { event in
                VStack(alignment: .leading, spacing: 10) {
                    Button { importEvent = event } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.headline)
                            Text(Date(timeIntervalSince1970: event.start / 1000).formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary)
                            if let host = event.host { Text(host.displayName).font(.caption).foregroundStyle(LaunchAppearance.palette.secondary) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                    HStack(spacing: 16) {
                        Button("Add to calendar") { importEvent = event }
                            .buttonStyle(.bordered).frame(minHeight: 44)
                        Button("Feedback") { feedbackEvent = event }
                            .buttonStyle(.borderless).frame(minHeight: 44)
                    }
                }
            }.listRowBackground(LaunchAppearance.palette.surface)
            if !loading && listings.isEmpty { Text(error ?? "No events yet.").font(.caption).foregroundStyle(LaunchAppearance.palette.secondary) }
            NavigationLink("See all events") { PublicEventsView(store: store) }
        }.listRowBackground(LaunchAppearance.palette.surface)
        .sheet(item: $importEvent) { listing in
            EventEditor(store: store, date: Date(timeIntervalSince1970: listing.start / 1000), draft: listing.calendarDraft).id(listing.id)
        }
        .sheet(item: $feedbackEvent) { EventFeedbackView(event: $0) }
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
