//
//  AuthProtocols.swift
//  wishywashy
//

import UIKit

enum LoginField {
    case email, password
}

enum RegisterField: CaseIterable {
    case name, email, password, confirm
}

struct RegisterForm {
    var name = ""
    var email = ""
    var password = ""
    var confirm = ""
}

/// The banner above the form
struct AuthBanner: Equatable {
    enum Style { case error, success }
    let message: String
    let style: Style
}

// MARK: - Login
// Presenter -> View
protocol LoginViewProtocol: AnyObject {
    func setLoading(_ isLoading: Bool)
    func showFieldError(_ message: String?, for field: LoginField)
    func showBanner(_ banner: AuthBanner?)
    func focus(_ field: LoginField)
}

// View -> Presenter
protocol LoginPresenterProtocol: AnyObject {
    func didFinishEditing(_ field: LoginField, email: String, password: String)
    func didTapSignIn(email: String, password: String)
    func didTapForgotPassword(email: String)
    func didTapCreateAccount()
}

// Presenter -> Interactor
protocol LoginInteractorInputProtocol: AnyObject {
    func signIn(email: String, password: String)
    func sendPasswordReset(email: String)
}

// Interactor -> Presenter
protocol LoginInteractorOutputProtocol: AnyObject {
    func didSignIn()
    func didSendPasswordReset()
    func didFail(_ error: AuthError)
}

// Presenter -> Router
protocol LoginRouterProtocol: AnyObject {
    func showRegister()
}

// MARK: - Register
// Presenter -> View
protocol RegisterViewProtocol: AnyObject {
    func setLoading(_ isLoading: Bool)
    func showFieldError(_ message: String?, for field: RegisterField)
    func showBanner(_ banner: AuthBanner?)
    func focus(_ field: RegisterField)
    func showCheckEmail(address: String)
}

// View -> Presenter
protocol RegisterPresenterProtocol: AnyObject {
    func didFinishEditing(_ field: RegisterField, form: RegisterForm)
    func didTapCreateAccount(form: RegisterForm)
    func didTapBackToSignIn()
}

// Presenter -> Interactor
protocol RegisterInteractorInputProtocol: AnyObject {
    func signUp(name: String, email: String, password: String)
}

// Interactor -> Presenter
protocol RegisterInteractorOutputProtocol: AnyObject {
    func didSignUp(_ result: SignUpResult)
    func didFail(_ error: AuthError)
}

// Presenter -> Router
protocol RegisterRouterProtocol: AnyObject {
    func showLogin()
}
