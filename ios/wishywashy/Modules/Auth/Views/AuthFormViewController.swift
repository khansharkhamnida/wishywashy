//
//  AuthFormViewController.swift
//  wishywashy
//
//  Shared page for Login and Register: scrolling content, a hero card, and keyboard handling that keeps
//  the focused field visible on small phones.
//

import UIKit

class AuthFormViewController: ProfilePageViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = false
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    func makeHero(title: String, subtitle: String) -> UIView {
        let card = GradientView()

        let emoji = UILabel()
        emoji.text = "🫧"
        emoji.font = Theme.font(34, .regular)
        emoji.isAccessibilityElement = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.font(28, .heavy)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = Theme.font(15, .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        subtitleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [emoji, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 20, left: 20, bottom: 22, right: 20))
        return card
    }

    func makeFormCard(_ fields: [UIView]) -> UIView {
        let card = CardView()
        let stack = UIStackView(arrangedSubviews: fields)
        stack.axis = .vertical
        stack.spacing = 14
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16))
        return card
    }

    /// "Already have an account?" style row with a text button
    func makeSwitchRow(prompt: String, action: String, onTap: @escaping () -> Void) -> UIView {
        let label = UILabel()
        label.text = prompt
        label.font = Theme.font(15, .medium)
        label.textColor = Theme.inkSoft

        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = action
        config.baseForegroundColor = Theme.Tone.pink.tint
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 4, bottom: 10, trailing: 4)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Theme.font(15, .bold)
            return attributes
        }
        button.configuration = config
        button.addAction(UIAction { _ in onTap() }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [label, button])
        row.spacing = 2
        row.alignment = .center
        let wrapper = UIStackView(arrangedSubviews: [UIView(), row, UIView()])
        wrapper.distribution = .equalCentering
        return wrapper
    }

    // MARK: - Keyboard
    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              view.window != nil else { return }
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curve = (note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? UIView.AnimationCurve.easeInOut.rawValue

        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        // The home indicator area is already inside the safe area, so only the rest needs adding
        let ownInset = view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom
        UIView.animate(withDuration: duration, delay: 0,
                       options: [UIView.AnimationOptions(rawValue: UInt(curve << 16)), .beginFromCurrentState]) {
            self.additionalSafeAreaInsets.bottom = max(0, overlap - ownInset)
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.scrollFocusedFieldIntoView()
        }
    }

    func scrollFocusedFieldIntoView() {
        guard let field = view.currentFirstResponder else { return }
        let rect = field.convert(field.bounds, to: scrollView)
        scrollView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -48), animated: true)
    }
}
