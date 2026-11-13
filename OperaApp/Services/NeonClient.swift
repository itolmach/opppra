//
//  NeonClient.swift
//  OperaApp
//
//  Talks to Neon's Data API and to Managed Better Auth, over URLSession.
//
//  This replaces SupabaseManager and the supabase-swift package. Neon
//  publishes no Swift SDK, and both services are ordinary REST, so the app
//  now has no third-party dependencies at all -- nothing to add in Xcode,
//  nothing to keep up to date, and no package resolution to go wrong.
//
//  Two tokens are in play and they are easy to confuse:
//
//    session token  long-lived, returned by sign-in, kept in the Keychain.
//                   It is what proves who you are to Better Auth.
//    JWT            short-lived, minted from the session by /token, and the
//                   only thing the Data API will accept. Never stored.
//
//  Keeping only the session on disk means a stolen backup yields a
//  credential that can be revoked server-side, rather than a bearer token
//  that works until it expires.
//

import Foundation

// MARK: - Errors

enum NeonError: LocalizedError {
    case notSignedIn
    /// The Data API answered with a PostgREST error body.
    case api(status: Int, code: String?, message: String)
    case auth(status: Int, code: String?, message: String)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You need to be signed in to do that."
        case let .api(status, code, message):
            // 42501 is Postgres' insufficient_privilege, which here means a
            // row level security policy refused the row -- worth naming,
            // because it reads as a bug otherwise.
            if code == "42501" {
                return "That change was refused: it would have touched a row that is not yours."
            }
            return "The server refused the request (\(status)): \(message)"
        case let .auth(status, code, message):
            switch code {
            case "INVALID_EMAIL_OR_PASSWORD": return "That email and password do not match."
            case "USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL": return "There is already an account with that email."
            case "INVALID_ORIGIN":
                return "This build's auth origin is not registered with the Neon project. See NEON_SETUP.md."
            default: return "Sign-in failed (\(status)): \(message)"
            }
        case let .transport(error):
            return error.localizedDescription
        case .decoding:
            return "The server sent something this version of the app could not read."
        }
    }
}

private struct PostgRESTError: Decodable {
    let code: String?
    let message: String
    let details: String?
    let hint: String?
}

private struct BetterAuthError: Decodable {
    let code: String?
    let message: String?
}

// MARK: - Token store

/// The session token, in the Keychain.
///
/// UserDefaults would have been three lines, and wrong: it lands in plain
/// text in unencrypted backups. `ThisDeviceOnly` keeps the token off other
/// devices restored from the same backup.
enum SessionStore {
    private static let service = "tech.neon.opera.session"
    private static let account = "better-auth-session"

    static func save(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty
        else { return nil }
        return token
    }

    static func clear() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
    }
}

// MARK: - Client

/// An actor, because the JWT cache is shared mutable state and every view
/// can hit it at once. Without this, a cold launch that fires several
/// requests would mint several JWTs in parallel.
actor NeonClient {
    static let shared = NeonClient()

    private let session: URLSession
    private var cachedJWT: String?
    private var jwtExpiry: Date?
    /// In-flight refresh, so concurrent callers await one request.
    private var refreshTask: Task<String, Error>?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = NeonClient.isoWithFraction.date(from: text) { return date }
            if let date = NeonClient.isoPlain.date(from: text) { return date }
            // Postgres `date` columns arrive as plain yyyy-MM-dd.
            if let date = NeonClient.dateOnly.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Unrecognised timestamp: \(text)")
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // Postgres returns timestamps with microseconds; ISO8601DateFormatter
    // needs to be told to expect them, and still refuses when they are
    // absent, hence two formatters rather than one.
    fileprivate static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    fileprivate static let isoPlain = ISO8601DateFormatter()
    fileprivate static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Auth

    var isSignedIn: Bool { SessionStore.load() != nil }

    /// Exchanges the stored session for a JWT, reusing the cached one until
    /// it is nearly expired. The sixty-second margin is for clock skew and
    /// for the request itself: a token that passes the check here and expires
    /// in flight fails at the server as a bare 401.
    func jwt() async throws -> String {
        if let token = cachedJWT, let expiry = jwtExpiry, expiry.timeIntervalSinceNow > 60 {
            return token
        }
        if let existing = refreshTask { return try await existing.value }

        let task = Task<String, Error> { [weak self] in
            guard let self else { throw NeonError.notSignedIn }
            return try await self.mintJWT()
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func mintJWT() async throws -> String {
        guard let sessionToken = SessionStore.load() else { throw NeonError.notSignedIn }

        var request = URLRequest(url: AppConfig.authURL.appendingPathComponent("token"))
        request.httpMethod = "GET"
        // Better Auth reads the session from a cookie, not a bearer header.
        request.setValue("better-auth.session_token=\(sessionToken)", forHTTPHeaderField: "Cookie")
        request.setValue(AppConfig.authOrigin, forHTTPHeaderField: "Origin")

        struct TokenResponse: Decodable { let token: String }
        let token: String = try await send(request, decodeAuth: TokenResponse.self).token

        cachedJWT = token
        jwtExpiry = Self.expiry(of: token)
        return token
    }

    /// Reads `exp` out of the JWT rather than assuming a lifetime, so a
    /// change in Neon's token policy does not quietly turn into 401s.
    private static func expiry(of jwt: String) -> Date {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return Date().addingTimeInterval(300) }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard
            let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let exp = json["exp"] as? TimeInterval
        else { return Date().addingTimeInterval(300) }
        return Date(timeIntervalSince1970: exp)
    }

    func signOut() {
        SessionStore.clear()
        cachedJWT = nil
        jwtExpiry = nil
    }

    func store(sessionToken: String) {
        SessionStore.save(sessionToken)
        cachedJWT = nil
        jwtExpiry = nil
    }

    /// POSTs to a Better Auth endpoint, e.g. "sign-in/email".
    func auth<T: Decodable>(_ path: String, body: [String: Any], as type: T.Type) async throws -> T {
        var request = URLRequest(url: AppConfig.authURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Required: without it Better Auth refuses with MISSING_ORIGIN.
        request.setValue(AppConfig.authOrigin, forHTTPHeaderField: "Origin")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request, decodeAuth: type)
    }

    // MARK: Data API

    /// GET against a table or view. `query` is PostgREST syntax, e.g.
    /// "select=title&order=title&limit=20".
    func get<T: Decodable>(_ path: String, query: String = "", as type: T.Type,
                           authenticated: Bool = true) async throws -> T {
        let request = try await dataRequest("GET", path: path, query: query,
                                            authenticated: authenticated)
        return try await send(request, decode: type)
    }

    @discardableResult
    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, as type: T.Type,
                                             returnRepresentation: Bool = true) async throws -> T {
        var request = try await dataRequest("POST", path: path, query: "", authenticated: true)
        request.setValue(returnRepresentation ? "return=representation" : "return=minimal",
                         forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        return try await send(request, decode: type)
    }

    @discardableResult
    func patch<Body: Encodable, T: Decodable>(_ path: String, query: String, body: Body,
                                              as type: T.Type) async throws -> T {
        var request = try await dataRequest("PATCH", path: path, query: query, authenticated: true)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        return try await send(request, decode: type)
    }

    func delete(_ path: String, query: String) async throws {
        let request = try await dataRequest("DELETE", path: path, query: query, authenticated: true)
        _ = try await sendRaw(request)
    }

    /// Number of matching rows, without downloading any of them.
    ///
    /// PostgREST reports it in Content-Range as "start-end/total", or
    /// "*/total" when limit=0, which is what this asks for -- the totals on
    /// the profile screen should not cost a full table read.
    ///
    /// `select` is separate from `filter` on purpose. Counting rows of one
    /// table by a column of another needs the join spelled inside the
    /// select ("id,user_lists!inner(type)") while the condition stays a
    /// normal filter; folding them into one string produces a query
    /// PostgREST rejects.
    func count(_ path: String, select: String = "id", filter: String = "") async throws -> Int {
        var parts = ["select=\(select)", "limit=0"]
        if !filter.isEmpty { parts.append(filter) }
        var request = try await dataRequest("GET", path: path,
                                            query: parts.joined(separator: "&"),
                                            authenticated: true)
        request.setValue("count=exact", forHTTPHeaderField: "Prefer")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NeonError.transport(error)
        }

        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let decoded = try? decoder.decode(PostgRESTError.self, from: data)
            throw NeonError.api(status: status, code: decoded?.code,
                                message: decoded?.message ?? Self.bodyText(data))
        }
        guard
            let range = http?.value(forHTTPHeaderField: "Content-Range"),
            let total = range.split(separator: "/").last,
            let value = Int(total)
        else { return 0 }
        return value
    }

    /// Calls a Postgres function exposed by the Data API, e.g.
    /// `ensure_user_bootstrap`.
    func rpc(_ name: String, body: [String: Any] = [:]) async throws {
        var request = try await dataRequest("POST", path: "rpc/\(name)", query: "",
                                            authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await sendRaw(request)
    }

    private func dataRequest(_ method: String, path: String, query: String,
                             authenticated: Bool) async throws -> URLRequest {
        var components = URLComponents(
            url: AppConfig.dataAPIURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.query = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated {
            request.setValue("Bearer \(try await jwt())", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: Transport

    private func sendRaw(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NeonError.transport(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let decoded = try? decoder.decode(PostgRESTError.self, from: data)
            throw NeonError.api(status: status, code: decoded?.code,
                                message: decoded?.message ?? Self.bodyText(data))
        }
        return data
    }

    private func send<T: Decodable>(_ request: URLRequest, decode type: T.Type) async throws -> T {
        let data = try await sendRaw(request)
        // 204 and an empty body are legitimate for a write with
        // return=minimal; decoding () from nothing has to work.
        if data.isEmpty, let empty = EmptyResponse() as? T { return empty }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NeonError.decoding(error)
        }
    }

    private func send<T: Decodable>(_ request: URLRequest, decodeAuth type: T.Type) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NeonError.transport(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let decoded = try? JSONDecoder().decode(BetterAuthError.self, from: data)
            throw NeonError.auth(status: status, code: decoded?.code,
                                 message: decoded?.message ?? Self.bodyText(data))
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NeonError.decoding(error)
        }
    }

    private static func bodyText(_ data: Data) -> String {
        String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(200)
            .description ?? "no response body"
    }
}

/// Stand-in for calls that return nothing.
struct EmptyResponse: Decodable {}
