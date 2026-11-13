//
//  RegisterInteractor.swift
//  wishywashy
//

import Foundation

final class RegisterInteractor: RegisterInteractorInputProtocol {
    weak var output: RegisterInteractorOutputProtocol?

    private let auth: AuthService

    init(auth: AuthService = Services.auth) {
        self.auth = auth
    }

    func signUp(name: String, email: String, password: String) {
        Task {
            do {
                output?.didSignUp(try await auth.signUp(name: name, email: email, password: password))
            } catch {
                output?.didFail(error as? AuthError ?? .unknown)
            }
        }
    }
}
