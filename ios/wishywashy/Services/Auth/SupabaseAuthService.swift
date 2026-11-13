//
//  SupabaseAuthService.swift
//  wishywashy
//
//  Email and password sign-in against the Supabase Auth REST API (GoTrue), with URLSession and no SDK.
//    POST /auth/v1/signup                        POST /auth/v1/token?grant_type=password
//    POST /auth/v1/token?grant_type=refresh_token  POST /auth/v1/logout?scope=local
//    GET  /auth/v1/user                          POST /auth/v1/recover
//  Tokens live in the Keychain through `AuthSessionStorage`. The anon key is a publishable key.
//

import Foundation

final class SupabaseAuthService: AuthService {
    let requiresSignIn = true

    private let config: SupabaseConfig?
    private let urlSession: URLSession
    private let storage: AuthSessionStorage
    private let notifications: NotificationCenter
    private let now: () -> Date
    private var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?

    init(config: SupabaseConfig?,
         urlSession: URLSession = .shared,
         storage: AuthSessionStorage = AuthSessionStorage(),
         notifications: NotificationCenter = .default,
         now: @escaping () -> Date = Date.init) {
        self.config = config
        self.urlSession = urlSession
        self.storage = storage
        self.notifications = notifications
        self.now = now
    }

    var currentUser: User? { session?.user }

    // MARK: - Sign up, sign in, sign out
    func signUp(name: String, email: String, password: String) async throws -> SignUpResult {
        let body: [String: Any] = ["email": email, "password": password, "data": ["display_name": name]]
        let (data, _) = try await send(path: "signup", body: body)

        // With email confirmation on (the hosted default) the response is a user and there is no session.
        // With it off, the response is a full session.
        if let token = try? Self.decoder.decode(TokenResponse.self, from: data) {
            begin(makeSession(token))
            return .signedIn
        }
        guard let remote = Self.decodeUser(from: data) else { throw AuthError.unknown }
        // Supabase hides whether an address is taken: for a confirmed account it answers 200 with no identities.
        if let identities = remote.identities, identities.isEmpty { throw AuthError.emailAlreadyRegistered }
        return .confirmationRequired(email: remote.email ?? email)
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> User {
        let (data, _) = try await send(path: "token",
                                       query: [URLQueryItem(name: "grant_type", value: "password")],
                                       body: ["email": email, "password": password])
        guard let token = try? Self.decoder.decode(TokenResponse.self, from: data) else { throw AuthError.unknown }
        let new = makeSession(token)
        begin(new)
        return new.user
    }

    func sendPasswordReset(email: String) async throws {
        _ = try await send(path: "recover", body: ["email": email])
    }

    func signOut() async {
        let token = (session ?? storage.load())?.accessToken
        endSession()
        guard let token else { return }
        // Best effort: the device is signed out whether or not the server hears about it
        _ = try? await send(path: "logout", query: [URLQueryItem(name: "scope", value: "local")], accessToken: token)
    }

    // MARK: - Keeping the session alive
    func restoreSession() async -> User? {
        guard config != nil, let stored = storage.load() else { return nil }
        session = stored

        if stored.isExpired(at: now()) {
            return await refreshKeepingSessionWhenOffline()
        }
        do {
            let (data, _) = try await send(path: "user", method: "GET", accessToken: stored.accessToken)
            if let remote = Self.decodeUser(from: data) {
                var updated = stored
                updated.user = Self.makeUser(remote, fallbackEmail: stored.user.email)
                session = updated
                storage.save(updated)
            }
        } catch AuthError.sessionExpired {
            return await refreshKeepingSessionWhenOffline()
        } catch {
            // Offline or a server hiccup: trust what is saved rather than signing the person out
        }
        return session?.user
    }

    func refresh() async throws -> User {
        try await refreshSession().user
    }

    func validAccessToken() async throws -> String {
        guard let current = session ?? storage.load() else { throw AuthError.sessionExpired }
        if session == nil { session = current }
        if current.isExpired(at: now()) { return try await refreshSession().accessToken }
        return current.accessToken
    }

    private func refreshKeepingSessionWhenOffline() async -> User? {
        _ = try? await refreshSession()
        return session?.user
    }

    /// Refresh tokens work once, so overlapping callers share one request
    private func refreshSession() async throws -> AuthSession {
        if let refreshTask { return try await refreshTask.value }
        guard let current = session ?? storage.load() else { throw AuthError.sessionExpired }

        let task = Task { try await requestRefresh(current.refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let refreshed = try await task.value
            session = refreshed
            storage.save(refreshed)
            return refreshed
        } catch let error as AuthError {
            // A bad refresh token is final. Offline, rate limits and server errors may pass, so keep the session.
            switch error {
            case .offline, .server, .rateLimited, .notConfigured: break
            default: endSession()
            }
            throw error
        }
    }

    private func requestRefresh(_ refreshToken: String) async throws -> AuthSession {
        let (data, _) = try await send(path: "token",
                                       query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                                       body: ["refresh_token": refreshToken])
        guard let token = try? Self.decoder.decode(TokenResponse.self, from: data) else { throw AuthError.unknown }
        return makeSession(token)
    }

    // MARK: - Session state
    private func begin(_ new: AuthSession) {
        session = new
        storage.save(new)
        notifications.post(name: .authStateDidChange, object: nil)
    }

    private func endSession() {
        let hadSession = session != nil
        session = nil
        storage.clear()
        if hadSession { notifications.post(name: .authStateDidChange, object: nil) }
    }

    private func makeSession(_ token: TokenResponse) -> AuthSession {
        // expires_in counts from receipt, so a wrong device clock cannot make a fresh token look old
        let lifetime = token.expiresIn.map(TimeInterval.init)
            ?? token.expiresAt.map { Date(timeIntervalSince1970: $0).timeIntervalSince(now()) }
            ?? 3600
        return AuthSession(accessToken: token.accessToken,
                           refreshToken: token.refreshToken,
                           expiresAt: now().addingTimeInterval(lifetime),
                           user: Self.makeUser(token.user, fallbackEmail: ""))
    }

    // MARK: - Network
    private func send(path: String,
                      method: String = "POST",
                      query: [URLQueryItem] = [],
                      body: [String: Any]? = nil,
                      accessToken: String? = nil) async throws -> (Data, Int) {
        guard let config else { throw AuthError.notConfigured }
        let request = try Self.makeRequest(config: config, path: path, method: method,
                                           query: query, body: body, accessToken: accessToken)
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AuthError.unknown }
            guard (200..<300).contains(http.statusCode) else {
                throw AuthError.map(status: http.statusCode, body: data)
            }
            return (data, http.statusCode)
        } catch let error as AuthError {
            throw error
        } catch let error as URLError {
            throw AuthError.map(urlError: error)
        } catch {
            throw AuthError.unknown
        }
    }

    static func makeRequest(config: SupabaseConfig, path: String, method: String,
                            query: [URLQueryItem] = [], body: [String: Any]? = nil,
                            accessToken: String? = nil) throws -> URLRequest {
        var components = URLComponents(url: config.url.appending(path: "auth/v1/\(path)"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = query.isEmpty ? nil : query
        guard let url = components?.url else { throw AuthError.notConfigured }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Newer publishable keys are not JWTs, so the anon key goes in `apikey` only. A user token goes in Authorization.
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        }
        return request
    }

    // MARK: - Decoding
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int?
        let expiresAt: Double?
        let user: RemoteUser
    }

    private struct RemoteUser: Decodable {
        struct Metadata: Decodable {
            let displayName: String?
            let fullName: String?
            let name: String?
        }
        struct Identity: Decodable {}

        let id: String
        let email: String?
        let phone: String?
        let userMetadata: Metadata?
        let identities: [Identity]?
    }

    private struct UserEnvelope: Decodable {
        let user: RemoteUser
    }

    private static func decodeUser(from data: Data) -> RemoteUser? {
        if let user = try? decoder.decode(RemoteUser.self, from: data) { return user }
        return (try? decoder.decode(UserEnvelope.self, from: data))?.user
    }

    private static func makeUser(_ remote: RemoteUser, fallbackEmail: String) -> User {
        let email = remote.email ?? fallbackEmail
        let candidates = [remote.userMetadata?.displayName, remote.userMetadata?.fullName, remote.userMetadata?.name,
                          email.split(separator: "@").first.map(String.init)]
        let name = candidates.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Friend"
        let phone = remote.phone?.isEmpty == false ? remote.phone : nil
        return User(id: remote.id, name: name, email: email, phoneNumber: phone)
    }
}

// MARK: - Error mapping
extension AuthError {
    /// Turns an error response into one of our cases. Supabase advises against relying on the message or the exact
    /// status code, so `error_code` comes first, then the message as a fallback for older servers.
    static func map(status: Int, body: Data) -> AuthError {
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        let code = (json["error_code"] as? String)?.lowercased() ?? ""
        let message = ["msg", "message", "error_description", "error"]
            .compactMap { json[$0] as? String }.joined(separator: " ").lowercased()

        switch code {
        case "invalid_credentials": return .invalidCredentials
        case "email_not_confirmed": return .emailNotConfirmed
        case "user_already_exists", "email_exists": return .emailAlreadyRegistered
        case "weak_password": return .weakPassword
        case "email_address_invalid": return .invalidEmail
        case "signup_disabled", "email_provider_disabled": return .signUpDisabled
        case "over_request_rate_limit", "over_email_send_rate_limit": return .rateLimited
        case "refresh_token_not_found", "refresh_token_already_used", "session_expired", "session_not_found",
             "bad_jwt", "user_not_found":
            return .sessionExpired
        default: break
        }

        if message.contains("invalid login credentials") { return .invalidCredentials }
        if message.contains("email not confirmed") { return .emailNotConfirmed }
        if message.contains("already registered") { return .emailAlreadyRegistered }
        if message.contains("password should be at least") || json["weak_password"] != nil { return .weakPassword }
        if message.contains("unable to validate email") || message.contains("invalid format") { return .invalidEmail }
        if message.contains("invalid refresh token") || message.contains("refresh token not found") { return .sessionExpired }

        switch status {
        case 429: return .rateLimited
        case 401: return .sessionExpired
        case 500...599: return .server
        default: return .unknown
        }
    }

    static func map(urlError error: URLError) -> AuthError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff, .secureConnectionFailed:
            return .offline
        default:
            return .unknown
        }
    }
}
