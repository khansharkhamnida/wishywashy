//
//  RegisterPresenter.swift
//  wishywashy
//

import Foundation

final class RegisterPresenter: RegisterPresenterProtocol, RegisterInteractorOutputProtocol {
    weak var view: RegisterViewProtocol?
    var interactor: RegisterInteractorInputProtocol?
    var router: RegisterRouterProtocol?

    private var isLoading = false

    func didFinishEditing(_ field: RegisterField, form: RegisterForm) {
        view?.showFieldError(error(for: field, in: form), for: field)
        // Changing the password can make an already typed confirmation wrong, or right
        if field == .password, !form.confirm.isEmpty {
            view?.showFieldError(error(for: .confirm, in: form), for: .confirm)
        }
    }

    func didTapCreateAccount(form: RegisterForm) {
        guard !isLoading else { return }
        view?.showBanner(nil)
        var firstInvalid: RegisterField?
        for field in RegisterField.allCases {
            let message = error(for: field, in: form)
            view?.showFieldError(message, for: field)
            if message != nil, firstInvalid == nil { firstInvalid = field }
        }
        if let firstInvalid { view?.focus(firstInvalid); return }

        setLoading(true)
        interactor?.signUp(name: form.name.trimmingCharacters(in: .whitespacesAndNewlines),
                           email: form.email.trimmingCharacters(in: .whitespacesAndNewlines),
                           password: form.password)
    }

    func didTapBackToSignIn() {
        router?.showLogin()
    }

    // RegisterInteractorOutputProtocol
    func didSignUp(_ result: SignUpResult) {
        switch result {
        case .signedIn:
            // The app swaps to the tab bar when the auth state changes. Leave the button loading until then.
            break
        case .confirmationRequired(let email):
            setLoading(false)
            view?.showCheckEmail(address: email)
        }
    }

    func didFail(_ error: AuthError) {
        setLoading(false)
        view?.showBanner(AuthBanner(message: AuthMessages.text(for: error), style: .error))
        switch error {
        case .emailAlreadyRegistered, .invalidEmail: view?.focus(.email)
        case .weakPassword: view?.focus(.password)
        default: break
        }
    }

    private func error(for field: RegisterField, in form: RegisterForm) -> String? {
        switch field {
        case .name: AuthValidation.name(form.name)
        case .email: AuthValidation.email(form.email)
        case .password: AuthValidation.newPassword(form.password)
        case .confirm: AuthValidation.confirmation(form.confirm, matches: form.password)
        }
    }

    private func setLoading(_ value: Bool) {
        isLoading = value
        view?.setLoading(value)
    }
}
