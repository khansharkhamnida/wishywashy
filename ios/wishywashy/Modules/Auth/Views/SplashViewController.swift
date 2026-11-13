//
//  SplashViewController.swift
//  wishywashy
//
//  Shown for a moment in live mode while the saved session is restored.
//

import UIKit

final class SplashViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        let emoji = UILabel()
        emoji.text = "🫧"
        emoji.font = Theme.font(56, .regular)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = Theme.pink
        spinner.startAnimating()
        spinner.accessibilityLabel = "Loading"

        let stack = UIStackView(arrangedSubviews: [emoji, spinner])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
