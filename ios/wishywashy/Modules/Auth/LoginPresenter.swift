//
//  LoginPresenter.swift
//  wishywashy
//

import Foundation

final class LoginPresenter: LoginPresenterProtocol, LoginInteractorOutputProtocol {
    weak var view: LoginViewProtocol?
    var interactor: LoginInteractorInputProtocol?
    var router: LoginRouterProtocol?

    private var isLoading = false

    func didFinishEditing(_ field: LoginField, email: String, password: String) {
        switch field {
        case .email: view?.showFieldError(AuthValidation.email(email), for: .email)
        case .password: view?.showFieldError(AuthValidation.existingPassword(password), for: .password)
        }
    }

    func didTapSignIn(email: String, password: String) {
        guard !isLoading else { return }
        view?.showBanner(nil)
        let emailError = AuthValidation.email(email)
        let passwordError = AuthValidation.existingPassword(password)
        view?.showFieldError(emailError, for: .email)
        view?.showFieldError(passwordError, for: .password)
        if emailError != nil { view?.focus(.email); return }
        if passwordError != nil { view?.focus(.password); return }

        setLoading(true)
        interactor?.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
    }

    func didTapForgotPassword(email: String) {
        guard !isLoading else { return }
        view?.showBanner(nil)
        let emailError = AuthValidation.email(email)
        view?.showFieldError(emailError, for: .email)
        if emailError != nil {
            view?.showBanner(AuthBanner(message: "Enter your email above and we'll send you a reset link.", style: .error))
            view?.focus(.email)
            return
        }
        setLoading(true)
        interactor?.sendPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func didTapCreateAccount() {
        router?.showRegister()
    }

    // LoginInteractorOutputProtocol
    func didSignIn() {
        // The app swaps to the tab bar when the auth state changes. Leave the button loading until then.
    }

    func didSendPasswordReset() {
        setLoading(false)
        view?.showBanner(AuthBanner(message: "If that email has an account, a reset link is on its way.", style: .success))
    }

    func didFail(_ error: AuthError) {
        setLoading(false)
        view?.showBanner(AuthBanner(message: AuthMessages.text(for: error), style: .error))
        if error == .invalidCredentials { view?.focus(.password) }
    }

    private func setLoading(_ value: Bool) {
        isLoading = value
        view?.setLoading(value)
    }
}
