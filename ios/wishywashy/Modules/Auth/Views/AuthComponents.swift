//
//  AuthComponents.swift
//  wishywashy
//
//  Building blocks for the Login and Register screens, in the same bubblegum style as the rest of the app.
//

import UIKit

/// A labelled text field with an ink outline, an inline error line and, for passwords, a show/hide button.
final class AuthFieldView: UIView, UITextFieldDelegate {
    enum Kind {
        case name, email, password(isNew: Bool)
    }

    let textField = UITextField()
    var onEndEditing: (() -> Void)?
    var onReturn: (() -> Void)?

    var text: String { textField.text ?? "" }

    private let container = UIView()
    private let errorLabel = UILabel()
    private let revealButton = UIButton(type: .system)
    private var hasError = false

    init(title: String, placeholder: String, kind: Kind, returnKey: UIReturnKeyType) {
        super.init(frame: .zero)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.font(14, .bold)
        titleLabel.textColor = Theme.inkSoft
        titleLabel.isAccessibilityElement = false

        textField.font = Theme.font(17, .medium)
        textField.textColor = Theme.ink
        textField.tintColor = Theme.pink
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder, attributes: [.foregroundColor: Theme.inkSoft, .font: Theme.font(17, .medium)])
        textField.returnKeyType = returnKey
        textField.delegate = self
        textField.accessibilityLabel = title
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        configure(kind)

        container.layer.cornerRadius = 16
        container.layer.cornerCurve = .continuous
        container.layer.borderWidth = 2.5
        container.backgroundColor = Theme.background
        container.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false

        var trailing = container.trailingAnchor
        var trailingGap: CGFloat = -14
        if case .password = kind {
            revealButton.setImage(UIImage(systemName: "eye.slash"), for: .normal)
            revealButton.tintColor = Theme.inkSoft
            revealButton.accessibilityLabel = "Show password"
            revealButton.addAction(UIAction { [weak self] _ in self?.toggleReveal() }, for: .touchUpInside)
            revealButton.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(revealButton)
            NSLayoutConstraint.activate([
                revealButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
                revealButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                revealButton.widthAnchor.constraint(equalToConstant: 44),
                revealButton.heightAnchor.constraint(equalToConstant: 44)
            ])
            trailing = revealButton.leadingAnchor
            trailingGap = 0
        }
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 52),
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: trailing, constant: trailingGap),
            textField.topAnchor.constraint(equalTo: container.topAnchor),
            textField.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        errorLabel.font = Theme.font(13, .semibold)
        errorLabel.textColor = Theme.Tone.pink.tint
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let stack = UIStackView(arrangedSubviews: [titleLabel, container, errorLabel])
        stack.axis = .vertical
        stack.spacing = 6
        addSubview(stack)
        stack.pin(to: self)

        updateBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: AuthFieldView, _) in
            view.updateBorder()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setError(_ message: String?) {
        hasError = message != nil
        errorLabel.text = message
        errorLabel.isHidden = message == nil
        // VoiceOver reads the message after the field name and value
        textField.accessibilityHint = message
        updateBorder()
    }

    private func configure(_ kind: Kind) {
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        switch kind {
        case .name:
            textField.autocapitalizationType = .words
            textField.textContentType = .name
        case .email:
            textField.keyboardType = .emailAddress
            textField.textContentType = .username
        case .password(let isNew):
            textField.isSecureTextEntry = true
            textField.textContentType = isNew ? .newPassword : .password
        }
    }

    private func toggleReveal() {
        textField.isSecureTextEntry.toggle()
        let revealed = !textField.isSecureTextEntry
        revealButton.setImage(UIImage(systemName: revealed ? "eye" : "eye.slash"), for: .normal)
        revealButton.accessibilityLabel = revealed ? "Hide password" : "Show password"
        // Toggling secure entry clears or mangles the text unless the field is refreshed
        let current = textField.text
        textField.text = nil
        textField.text = current
    }

    @objc private func editingChanged() {
        if hasError { setError(nil) }
    }

    private func updateBorder() {
        let color = hasError ? Theme.Tone.pink.tint : Theme.ink
        container.layer.borderColor = color.resolvedColor(with: traitCollection).cgColor
    }

    func textFieldDidBeginEditing(_ textField: UITextField) { updateBorderFocused(true) }

    func textFieldDidEndEditing(_ textField: UITextField) {
        updateBorderFocused(false)
        onEndEditing?()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturn?()
        return false
    }

    private func updateBorderFocused(_ focused: Bool) {
        container.layer.borderWidth = focused ? 3.5 : 2.5
    }
}

/// Pink pill button that swaps its title for a spinner while a request runs.
final class AuthPrimaryButton: UIButton {
    private let idleTitle: String
    private let loadingTitle: String

    init(title: String, loadingTitle: String) {
        idleTitle = title
        self.loadingTitle = loadingTitle
        super.init(frame: .zero)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = Theme.pink
        config.baseForegroundColor = .white
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20)
        config.imagePadding = 10
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Theme.font(17, .bold)
            return attributes
        }
        configuration = config
        accessibilityLabel = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setLoading(_ isLoading: Bool) {
        configuration?.showsActivityIndicator = isLoading
        configuration?.title = isLoading ? loadingTitle : idleTitle
        isEnabled = !isLoading
        accessibilityLabel = isLoading ? loadingTitle : idleTitle
        accessibilityTraits = isLoading ? [.button, .notEnabled] : .button
    }
}

/// Message strip shown above the form: pink for errors, mint for good news.
final class AuthBannerView: UIView {
    private let label = UILabel()
    private let icon = UIImageView()
    private let card = CardView(radius: 18)

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = Theme.font(15, .semibold)
        label.textColor = Theme.ink
        label.numberOfLines = 0
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 12
        row.alignment = .center
        card.addSubview(row)
        row.pin(to: card, insets: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        addSubview(card)
        card.pin(to: self, insets: UIEdgeInsets(top: 0, left: 0, bottom: 5, right: 0))
        isHidden = true
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(_ banner: AuthBanner?) {
        guard let banner else {
            isHidden = true
            return
        }
        let tone: Theme.Tone = banner.style == .error ? .pink : .mint
        card.fill = tone.soft
        icon.image = UIImage(systemName: banner.style == .error ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
        icon.tintColor = tone.tint
        label.text = banner.message
        accessibilityLabel = banner.message
        isHidden = false
        UIAccessibility.post(notification: .announcement, argument: banner.message)
    }
}

extension UIView {
    var currentFirstResponder: UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let found = subview.currentFirstResponder { return found }
        }
        return nil
    }
}
