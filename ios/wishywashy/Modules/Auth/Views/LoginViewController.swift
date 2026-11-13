//
//  LoginViewController.swift
//  wishywashy
//
//  Email and password sign-in.
//

import UIKit

final class LoginViewController: AuthFormViewController {
    var presenter: LoginPresenterProtocol?

    private let banner = AuthBannerView()
    private let emailField = AuthFieldView(title: "Email", placeholder: "you@example.com",
                                           kind: .email, returnKey: .next)
    private let passwordField = AuthFieldView(title: "Password", placeholder: "Your password",
                                              kind: .password(isNew: false), returnKey: .go)
    private let signInButton = AuthPrimaryButton(title: "Sign in", loadingTitle: "Signing in…")
    private let forgotButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()

        emailField.onReturn = { [weak self] in self?.passwordField.textField.becomeFirstResponder() }
        passwordField.onReturn = { [weak self] in self?.submit() }
        emailField.onEndEditing = { [weak self] in
            guard let self else { return }
            self.presenter?.didFinishEditing(.email, email: self.emailField.text, password: self.passwordField.text)
        }
        // The password is only checked on submit, so moving on from an empty field does not scold

        var config = UIButton.Configuration.plain()
        config.title = "Forgot password?"
        config.baseForegroundColor = Theme.Tone.pink.tint
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Theme.font(14, .bold)
            return attributes
        }
        forgotButton.configuration = config
        forgotButton.contentHorizontalAlignment = .trailing
        forgotButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.view.endEditing(true)
            self.presenter?.didTapForgotPassword(email: self.emailField.text)
        }, for: .touchUpInside)

        signInButton.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)

        setContent([
            makeHero(title: "Welcome back!", subtitle: "Sign in to reserve machines and track your cycles."),
            banner,
            makeFormCard([emailField, passwordField, forgotButton]),
            signInButton,
            makeSwitchRow(prompt: "New here?", action: "Create an account") { [weak self] in
                self?.presenter?.didTapCreateAccount()
            }
        ])
    }

    private func submit() {
        view.endEditing(true)
        presenter?.didTapSignIn(email: emailField.text, password: passwordField.text)
    }
}

extension LoginViewController: LoginViewProtocol {
    func setLoading(_ isLoading: Bool) {
        signInButton.setLoading(isLoading)
        forgotButton.isEnabled = !isLoading
        emailField.isUserInteractionEnabled = !isLoading
        passwordField.isUserInteractionEnabled = !isLoading
    }

    func showFieldError(_ message: String?, for field: LoginField) {
        (field == .email ? emailField : passwordField).setError(message)
    }

    func showBanner(_ banner: AuthBanner?) {
        self.banner.show(banner)
    }

    func focus(_ field: LoginField) {
        (field == .email ? emailField : passwordField).textField.becomeFirstResponder()
    }
}

#Preview {
    LoginRouter.createModule()
}
