//
//  AuthService.swift
//  wishywashy
//
//  Who is signed in. Screens and interactors only know this protocol.
//  `SampleAuthService` is always signed in as the fixed sample user; `SupabaseAuthService` talks to Supabase Auth.
//

import Foundation

extension Notification.Name {
    /// Posted whenever someone signs in, signs out, or the session can no longer be kept alive
    static let authStateDidChange = Notification.Name("wishywashy.authStateDidChange")
}

/// What the app keeps between launches (in the Keychain, never UserDefaults)
struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var user: User

    func isExpired(at now: Date, leeway: TimeInterval = 60) -> Bool {
        expiresAt.timeIntervalSince(now) <= leeway
    }
}

enum SignUpResult: Equatable {
    case signedIn
    /// Supabase asks new users to confirm their email first, so there is no session yet
    case confirmationRequired(email: String)
}

enum AuthError: Error, Equatable {
    case invalidCredentials
    case emailNotConfirmed
    case emailAlreadyRegistered
    case invalidEmail
    case weakPassword
    case signUpDisabled
    case rateLimited
    case offline
    case sessionExpired
    case notConfigured
    case server
    case unknown
}

protocol AuthService: AnyObject {
    /// False in sample mode: there is no login and the app opens straight on the tab bar
    var requiresSignIn: Bool { get }
    var currentUser: User? { get }

    func signUp(name: String, email: String, password: String) async throws -> SignUpResult
    @discardableResult
    func signIn(email: String, password: String) async throws -> User
    func sendPasswordReset(email: String) async throws
    func signOut() async
    /// Loads the saved session at launch and refreshes it if it has expired
    func restoreSession() async -> User?
    /// Swaps the refresh token for a new access token
    func refresh() async throws -> User
    /// A token that is valid now, refreshed first if needed. For services that call the backend.
    func validAccessToken() async throws -> String
}
