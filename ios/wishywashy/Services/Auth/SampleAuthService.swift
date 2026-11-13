//
//  SampleAuthService.swift
//  wishywashy
//

import Foundation

/// Sample mode: always "signed in" as the fixed sample user. Nothing is stored and no screens appear.
final class SampleAuthService: AuthService {
    let requiresSignIn = false
    let currentUser: User? = Session.sampleUser

    func signUp(name: String, email: String, password: String) async throws -> SignUpResult { .signedIn }
    func signIn(email: String, password: String) async throws -> User { Session.sampleUser }
    func sendPasswordReset(email: String) async throws {}
    func signOut() async {}
    func restoreSession() async -> User? { Session.sampleUser }
    func refresh() async throws -> User { Session.sampleUser }
    func validAccessToken() async throws -> String { throw AuthError.notConfigured }
}
