import Foundation
import Observation
import Security

@MainActor @Observable
final class ConvexAccount {
    static let shared = ConvexAccount()
    static let baseURL = URL(string: "https://majestic-vulture-890.convex.cloud")!
    private(set) var username: String?
    private var session: Session?
    private struct Session: Codable { var token: String; var refreshToken: String; var username: String }
    private let service = "systems.edmundlim.daymark.convex"

    init() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session", kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data, let stored = try? JSONDecoder().decode(Session.self, from: data) {
            session = stored; username = stored.username
        }
    }

    func signIn(username: String, password: String, create: Bool) async throws {
        let normalized = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await call(kind: "action", path: "auth:signIn", args: ["provider": "password", "params": ["username": normalized, "password": password, "flow": create ? "signUp" : "signIn"]])
        try saveTokens(result, username: normalized)
    }

    func signOut() async {
        if let session { _ = try? await call(kind: "action", path: "auth:signOut", args: [:], token: session.token) }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        SecItemDelete(query as CFDictionary)
        session = nil; username = nil
    }

    func publish(title: String, description: String, start: Date, end: Date, location: String, tags: [String], host: String, bio: String) async throws {
        let token = try await validToken()
        _ = try await call(kind: "mutation", path: "discovery:saveHost", args: ["displayName": host, "bio": bio], token: token)
        _ = try await call(kind: "mutation", path: "discovery:publish", args: ["title": title, "description": description, "start": start.timeIntervalSince1970 * 1000, "end": end.timeIntervalSince1970 * 1000, "location": location, "tags": tags, "published": true], token: token)
    }

    private func validToken() async throws -> String {
        guard let session else { throw AccountError.message("Sign in to publish public events.") }
        let parts = session.token.split(separator: ".")
        if parts.count > 1 {
            var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
            if let data = Data(base64Encoded: base64), let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let expiry = payload["exp"] as? Double, expiry > Date().timeIntervalSince1970 + 60 { return session.token }
        }
        let response = try await call(kind: "action", path: "auth:signIn", args: ["refreshToken": session.refreshToken])
        try saveTokens(response, username: session.username)
        guard let refreshed = self.session else { throw AccountError.message("Please sign in again.") }
        return refreshed.token
    }

    private func saveTokens(_ response: [String: Any], username: String) throws {
        guard let tokens = response["tokens"] as? [String: Any], let token = tokens["token"] as? String, let refresh = tokens["refreshToken"] as? String else { throw AccountError.message("Sign-in did not return a session. Try again.") }
        let stored = Session(token: token, refreshToken: refresh, username: username)
        let data = try JSONEncoder().encode(stored)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else { throw AccountError.message("Couldn’t securely save your session.") }
        } else if update != errSecSuccess { throw AccountError.message("Couldn’t securely save your session.") }
        session = stored; self.username = username
    }

    private func call(kind: String, path: String, args: [String: Any], token: String? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api/" + kind))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: ["path": path, "args": args, "format": "json"])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AccountError.message("Couldn’t connect. Check your internet connection and try again.") }
        guard result["status"] as? String == "success" else {
            let message = result["errorData"] as? String ?? result["errorMessage"] as? String ?? "Request failed."
            if message.contains("InvalidAccountId") || message.contains("InvalidSecret") { throw AccountError.message("Incorrect username or password.") }
            throw AccountError.message(message)
        }
        return result["value"] as? [String: Any] ?? [:]
    }
}

private enum AccountError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let message): return message } }
}
