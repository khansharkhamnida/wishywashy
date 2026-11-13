//
//  LoginInteractor.swift
//  wishywashy
//

import Foundation

final class LoginInteractor: LoginInteractorInputProtocol {
    weak var output: LoginInteractorOutputProtocol?

    private let auth: AuthService

    init(auth: AuthService = Services.auth) {
        self.auth = auth
    }

    func signIn(email: String, password: String) {
        Task {
            do {
                try await auth.signIn(email: email, password: password)
                output?.didSignIn()
            } catch {
                output?.didFail(error as? AuthError ?? .unknown)
            }
        }
    }

    func sendPasswordReset(email: String) {
        Task {
            do {
                try await auth.sendPasswordReset(email: email)
                output?.didSendPasswordReset()
            } catch {
                output?.didFail(error as? AuthError ?? .unknown)
            }
        }
    }
}
