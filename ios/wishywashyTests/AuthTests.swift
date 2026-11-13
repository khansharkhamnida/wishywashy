//
//  AuthTests.swift
//  wishywashyTests
//
//  Auth runs against a fake network (no Supabase project) and a fake Keychain.
//

import Foundation
import Testing
@testable import wishywashy

// MARK: - Fakes
private final class MemorySecureStore: SecureStore {
    var items: [String: Data] = [:]
    func data(forKey key: String) -> Data? { items[key] }
    func set(_ data: Data, forKey key: String) -> Bool { items[key] = data; return true }
    func remove(forKey key: String) { items[key] = nil }
}

private final class StubURLProtocol: URLProtocol {
    typealias Reply = (statusCode: Int, body: String)
    nonisolated(unsafe) static var handler: ((URLRequest) -> Reply)?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        let reply: Reply = Self.handler?(request) ?? (statusCode: 500, body: "{}")
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.statusCode,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private let tokenBody = """
{"access_token":"ACCESS-1","refresh_token":"REFRESH-1","expires_in":3600,"token_type":"bearer",
 "user":{"id":"user-1","email":"mia@example.com","user_metadata":{"display_name":"Mia"},"identities":[{}]}}
"""

@Suite(.serialized)
final class SupabaseAuthServiceTests {
    private let secure = MemorySecureStore()
    private let config = SupabaseConfig(url: URL(string: "https://YOUR-PROJECT-REF.supabase.co")!,
                                        anonKey: "YOUR-ANON-OR-PUBLISHABLE-KEY")
    private let notifications = NotificationCenter()
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    init() {
        StubURLProtocol.handler = nil
        StubURLProtocol.requests = []
    }

    private func makeService(config: SupabaseConfig?? = nil, now: Date? = nil) -> SupabaseAuthService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let date = now ?? clock
        return SupabaseAuthService(config: config ?? self.config,
                                   urlSession: URLSession(configuration: configuration),
                                   storage: AuthSessionStorage(store: secure),
                                   notifications: notifications,
                                   now: { date })
    }

    @Test func signInStoresSessionInSecureStoreAndSetsUser() async throws {
        StubURLProtocol.handler = { _ in (200, tokenBody) }
        let service = makeService()

        let user = try await service.signIn(email: "mia@example.com", password: "correct horse")

        #expect(user.name == "Mia")
        #expect(user.id == "user-1")
        #expect(service.currentUser?.email == "mia@example.com")
        #expect(secure.items[AuthSessionStorage.key] != nil)
    }

    @Test func requestsCarryTheKeyInApikeyAndNoSecretIsInTheUrl() async throws {
        StubURLProtocol.handler = { _ in (200, tokenBody) }
        _ = try await makeService().signIn(email: "mia@example.com", password: "correct horse")

        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.value(forHTTPHeaderField: "apikey") == "YOUR-ANON-OR-PUBLISHABLE-KEY")
        #expect(request.url?.path == "/auth/v1/token")
        #expect(request.url?.query == "grant_type=password")
        #expect(request.url?.absoluteString.contains("correct horse") == false)
    }

    @Test func wrongPasswordMapsToFriendlyError() async {
        StubURLProtocol.handler = { _ in
            (400, #"{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#)
        }
        let service = makeService()

        await #expect(throws: AuthError.invalidCredentials) {
            try await service.signIn(email: "mia@example.com", password: "nope")
        }
        #expect(service.currentUser == nil)
        #expect(secure.items.isEmpty)
    }

    @Test func signUpWithEmailConfirmationReturnsNoSession() async throws {
        StubURLProtocol.handler = { _ in
            (200, #"{"id":"user-2","email":"new@example.com","identities":[{}],"user_metadata":{"display_name":"New"}}"#)
        }
        let service = makeService()

        let result = try await service.signUp(name: "New", email: "new@example.com", password: "longenough1")

        #expect(result == .confirmationRequired(email: "new@example.com"))
        #expect(service.currentUser == nil)
        #expect(secure.items.isEmpty)
    }

    @Test func signUpSendsTheDisplayNameTheProfileTriggerReads() async throws {
        StubURLProtocol.handler = { _ in
            (200, #"{"id":"user-2","email":"new@example.com","identities":[{}]}"#)
        }
        _ = try await makeService().signUp(name: "New", email: "new@example.com", password: "longenough1")

        let body = try #require(StubURLProtocol.requests.first?.httpBody
                                ?? StubURLProtocol.requests.first?.httpBodyStream.map(Self.read))
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let data = try #require(json["data"] as? [String: String])
        #expect(data["display_name"] == "New")
    }

    @Test func signUpForAnExistingEmailIsReportedAsTaken() async {
        // Supabase answers 200 with no identities when the address already has a confirmed account
        StubURLProtocol.handler = { _ in (200, #"{"id":"user-3","email":"mia@example.com","identities":[]}"#) }
        let service = makeService()

        await #expect(throws: AuthError.emailAlreadyRegistered) {
            try await service.signUp(name: "Mia", email: "mia@example.com", password: "longenough1")
        }
    }

    @Test func signOutClearsSessionEvenWhenOffline() async throws {
        StubURLProtocol.handler = { _ in (200, tokenBody) }
        let service = makeService()
        try await service.signIn(email: "mia@example.com", password: "correct horse")

        StubURLProtocol.handler = { _ in (500, "{}") }
        await service.signOut()

        #expect(service.currentUser == nil)
        #expect(secure.items.isEmpty)
    }

    @Test func restoreSessionRefreshesAnExpiredToken() async throws {
        StubURLProtocol.handler = { _ in (200, tokenBody) }
        try await makeService().signIn(email: "mia@example.com", password: "correct horse")

        let refreshed = """
        {"access_token":"ACCESS-2","refresh_token":"REFRESH-2","expires_in":3600,
         "user":{"id":"user-1","email":"mia@example.com","user_metadata":{"display_name":"Mia"}}}
        """
        StubURLProtocol.handler = { _ in (200, refreshed) }
        let later = makeService(now: clock.addingTimeInterval(7200))

        let user = await later.restoreSession()

        #expect(user?.id == "user-1")
        #expect(try await later.validAccessToken() == "ACCESS-2")
    }

    @Test func aRejectedRefreshTokenSignsTheDeviceOut() async throws {
        StubURLProtocol.handler = { _ in (200, tokenBody) }
        try await makeService().signIn(email: "mia@example.com", password: "correct horse")

        StubURLProtocol.handler = { _ in
            (400, #"{"error_code":"refresh_token_not_found","msg":"Invalid Refresh Token: Refresh Token Not Found"}"#)
        }
        let later = makeService(now: clock.addingTimeInterval(7200))

        #expect(await later.restoreSession() == nil)
        #expect(secure.items.isEmpty)
    }

    @Test func offlineDuringRefreshKeepsTheSavedSession() async throws {
        StubURLProtocol.handler = { _ in (200, tokenBody) }
        try await makeService().signIn(email: "mia@example.com", password: "correct horse")

        StubURLProtocol.handler = { _ in (503, "{}") }
        let later = makeService(now: clock.addingTimeInterval(7200))

        #expect(await later.restoreSession()?.id == "user-1")
        #expect(secure.items[AuthSessionStorage.key] != nil)
    }

    @Test func withoutConfigNothingIsSent() async {
        let service = makeService(config: .some(nil))

        await #expect(throws: AuthError.notConfigured) {
            try await service.signIn(email: "mia@example.com", password: "correct horse")
        }
        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test func errorCodesMapToCases() {
        func map(_ status: Int, _ json: String) -> AuthError { AuthError.map(status: status, body: Data(json.utf8)) }
        #expect(map(400, #"{"error_code":"email_not_confirmed"}"#) == .emailNotConfirmed)
        #expect(map(422, #"{"error_code":"weak_password"}"#) == .weakPassword)
        #expect(map(422, #"{"error_code":"user_already_exists"}"#) == .emailAlreadyRegistered)
        #expect(map(429, #"{"error_code":"over_email_send_rate_limit"}"#) == .rateLimited)
        #expect(map(400, #"{"msg":"Invalid login credentials"}"#) == .invalidCredentials)
        #expect(map(502, "not json") == .server)
        #expect(map(418, "{}") == .unknown)
    }

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

// MARK: - Form rules, messages, config
struct AuthValidationTests {
    @Test func emailRules() {
        #expect(AuthValidation.email("") != nil)
        #expect(AuthValidation.email("mia") != nil)
        #expect(AuthValidation.email("mia@") != nil)
        #expect(AuthValidation.email("mia@example") != nil)
        #expect(AuthValidation.email("mia@exa mple.com") != nil)
        #expect(AuthValidation.email("  mia@example.com ") == nil)
        #expect(AuthValidation.email("mia.k+wash@mail.example.sg") == nil)
    }

    @Test func nameRules() {
        #expect(AuthValidation.name("   ") != nil)
        #expect(AuthValidation.name(String(repeating: "a", count: 51)) != nil)
        #expect(AuthValidation.name("Mia") == nil)
    }

    @Test func passwordRules() {
        #expect(AuthValidation.newPassword("") != nil)
        #expect(AuthValidation.newPassword("short") != nil)
        #expect(AuthValidation.newPassword("longenough") == nil)
        #expect(AuthValidation.existingPassword("") != nil)
        #expect(AuthValidation.existingPassword("x") == nil)
    }

    @Test func confirmationMustMatch() {
        #expect(AuthValidation.confirmation("", matches: "abc12345") != nil)
        #expect(AuthValidation.confirmation("abc1234", matches: "abc12345") != nil)
        #expect(AuthValidation.confirmation("abc12345", matches: "abc12345") == nil)
    }

    @Test func everyErrorHasAFriendlyMessage() {
        let all: [AuthError] = [.invalidCredentials, .emailNotConfirmed, .emailAlreadyRegistered, .invalidEmail,
                                .weakPassword, .signUpDisabled, .rateLimited, .offline, .sessionExpired,
                                .notConfigured, .server, .unknown]
        for error in all {
            #expect(!AuthMessages.text(for: error).isEmpty)
        }
    }
}

struct AppConfigTests {
    private func defaults(_ values: [String: String]) -> UserDefaults {
        let suite = "AppConfigTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        for (key, value) in values { defaults.set(value, forKey: key) }
        return defaults
    }

    @Test func sampleIsTheDefault() {
        let config = AppConfig(defaults: defaults([:]))
        #expect(config.dataSource == .sample)
        #expect(!config.isLive)
        #expect(config.supabase == nil)
    }

    @Test func liveNeedsBothArguments() {
        #expect(AppConfig(defaults: defaults(["dataSource": "live"])).supabase == nil)
        #expect(AppConfig(defaults: defaults(["dataSource": "live", "supabaseURL": "https://YOUR-PROJECT-REF.supabase.co"])).supabase == nil)

        let full = AppConfig(defaults: defaults(["dataSource": "live",
                                                 "supabaseURL": "https://YOUR-PROJECT-REF.supabase.co",
                                                 "supabaseAnonKey": "YOUR-ANON-OR-PUBLISHABLE-KEY"]))
        #expect(full.isLive)
        #expect(full.supabase?.url.host == "YOUR-PROJECT-REF.supabase.co")
    }

    @Test func aBadUrlIsIgnored() {
        let config = AppConfig(defaults: defaults(["dataSource": "live", "supabaseURL": "not a url",
                                                   "supabaseAnonKey": "YOUR-ANON-OR-PUBLISHABLE-KEY"]))
        #expect(config.supabase == nil)
    }
}

struct SampleAuthServiceTests {
    @Test func sampleModeNeedsNoSignInAndKeepsTheSampleUser() async {
        let service = SampleAuthService()
        #expect(!service.requiresSignIn)
        #expect(service.currentUser?.id == Session.sampleUser.id)
        #expect(await service.restoreSession()?.name == "Shofia")
    }
}
