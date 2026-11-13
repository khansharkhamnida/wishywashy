//
//  RegisterViewController.swift
//  wishywashy
//
//  Create an account with a display name, email and password.
//

import UIKit

final class RegisterViewController: AuthFormViewController {
    var presenter: RegisterPresenterProtocol?

    private let banner = AuthBannerView()
    private let nameField = AuthFieldView(title: "Display name", placeholder: "What should we call you?",
                                          kind: .name, returnKey: .next)
    private let emailField = AuthFieldView(title: "Email", placeholder: "you@example.com",
                                           kind: .email, returnKey: .next)
    private let passwordField = AuthFieldView(title: "Password", placeholder: "At least 8 characters",
                                              kind: .password(isNew: true), returnKey: .next)
    private let confirmField = AuthFieldView(title: "Confirm password", placeholder: "Type it again",
                                             kind: .password(isNew: true), returnKey: .go)
    private let createButton = AuthPrimaryButton(title: "Create account", loadingTitle: "Creating account…")

    private var form: RegisterForm {
        RegisterForm(name: nameField.text, email: emailField.text,
                     password: passwordField.text, confirm: confirmField.text)
    }

    private func field(_ field: RegisterField) -> AuthFieldView {
        switch field {
        case .name: nameField
        case .email: emailField
        case .password: passwordField
        case .confirm: confirmField
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let order: [RegisterField] = [.name, .email, .password, .confirm]
        for (index, kind) in order.enumerated() {
            let current = field(kind)
            current.onEndEditing = { [weak self] in
                guard let self else { return }
                self.presenter?.didFinishEditing(kind, form: self.form)
            }
            current.onReturn = { [weak self] in
                guard let self else { return }
                if index + 1 < order.count {
                    self.field(order[index + 1]).textField.becomeFirstResponder()
                } else {
                    self.submit()
                }
            }
        }

        createButton.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)

        setContent(formContent())
    }

    private func formContent() -> [UIView] {
        [
            makeHero(title: "Join the wash crew", subtitle: "Create an account to start reserving machines."),
            banner,
            makeFormCard([nameField, emailField, passwordField, confirmField]),
            createButton,
            makeSwitchRow(prompt: "Already have an account?", action: "Sign in") { [weak self] in
                self?.presenter?.didTapBackToSignIn()
            }
        ]
    }

    private func submit() {
        view.endEditing(true)
        presenter?.didTapCreateAccount(form: form)
    }
}

extension RegisterViewController: RegisterViewProtocol {
    func setLoading(_ isLoading: Bool) {
        createButton.setLoading(isLoading)
        RegisterField.allCases.forEach { field($0).isUserInteractionEnabled = !isLoading }
    }

    func showFieldError(_ message: String?, for field: RegisterField) {
        self.field(field).setError(message)
    }

    func showBanner(_ banner: AuthBanner?) {
        self.banner.show(banner)
    }

    func focus(_ field: RegisterField) {
        self.field(field).textField.becomeFirstResponder()
    }

    func showCheckEmail(address: String) {
        view.endEditing(true)
        let icon = IconBubble(size: 64, symbolSize: 28)
        icon.configure(symbol: "envelope.badge.fill", tone: .mint)

        let title = UILabel()
        title.text = "Check your email"
        title.font = Theme.font(24, .heavy)
        title.textColor = Theme.ink
        title.numberOfLines = 0
        title.accessibilityTraits = .header

        let message = ProfileUI.caption("We sent a confirmation link to \(address). Open it, then come back and sign in.")
        message.font = Theme.font(16, .medium)

        let stack = UIStackView(arrangedSubviews: [icon, title, message])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        let card = CardView()
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 22, left: 20, bottom: 22, right: 20))

        let back = AuthPrimaryButton(title: "Back to sign in", loadingTitle: "Back to sign in")
        back.addAction(UIAction { [weak self] _ in self?.presenter?.didTapBackToSignIn() }, for: .touchUpInside)

        setContent([makeHero(title: "Almost there!", subtitle: "One more step before you can sign in."), card, back])
        UIAccessibility.post(notification: .screenChanged, argument: title)
    }
}

#Preview {
    RegisterRouter.createModule()
}
