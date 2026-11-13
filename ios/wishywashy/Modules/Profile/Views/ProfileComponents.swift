//
//  ProfileComponents.swift
//  wishywashy
//
//  Shared building blocks for the Profile page and its sub-pages.
//

import UIKit

/// Scrolling page with a vertical stack, used by Profile and every page opened from it.
class ProfilePageViewController: UIViewController {

    let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        contentStack.axis = .vertical
        contentStack.spacing = 20

        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    /// Replaces everything on the page, so sub-pages can simply rebuild after a change.
    func setContent(_ views: [UIView]) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        views.forEach { contentStack.addArrangedSubview($0) }
    }

    /// Action sheets crash on iPad without a popover anchor.
    func present(sheet: UIAlertController) {
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        present(sheet, animated: true)
    }
}

/// One row: icon bubble, title, optional subtitle and an optional accessory on the right.
final class ProfileRowView: UIView {
    private let onTap: (() -> Void)?

    init(title: String, subtitle: String? = nil, symbol: String, tone: Theme.Tone,
         accessory: UIView? = nil, onTap: (() -> Void)? = nil) {
        self.onTap = onTap
        super.init(frame: .zero)

        let bubble = IconBubble(size: 44, symbolSize: 18)
        bubble.configure(symbol: symbol, tone: tone)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.font(17, .semibold)
        titleLabel.textColor = Theme.ink

        let texts = UIStackView(arrangedSubviews: [titleLabel])
        texts.axis = .vertical
        texts.spacing = 2
        if let subtitle {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.font = Theme.font(13, .medium)
            subtitleLabel.textColor = Theme.inkSoft
            texts.addArrangedSubview(subtitleLabel)
        }

        let row = UIStackView(arrangedSubviews: [bubble, texts] + (accessory.map { [$0] } ?? []))
        row.spacing = 16
        row.alignment = .center
        addSubview(row)
        row.pin(to: self, insets: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))

        if onTap != nil {
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() { onTap?() }
}

enum ProfileUI {
    static func chevron() -> UIView {
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Theme.inkSoft
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        return chevron
    }

    /// A card holding rows separated by dividers.
    static func card(rows: [UIView]) -> UIView {
        let card = CardView()
        let stack = UIStackView()
        stack.axis = .vertical
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = Theme.stroke
                divider.heightAnchor.constraint(equalToConstant: 1.5).isActive = true
                let wrapper = UIView()
                wrapper.addSubview(divider)
                divider.pin(to: wrapper, insets: UIEdgeInsets(top: 0, left: 76, bottom: 0, right: 16))
                stack.addArrangedSubview(wrapper)
            }
            stack.addArrangedSubview(row)
        }
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0))
        return card
    }

    static func sectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = Theme.font(20, .bold)
        label.textColor = Theme.ink
        return label
    }

    static func caption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = Theme.font(14, .medium)
        label.textColor = Theme.inkSoft
        label.numberOfLines = 0
        return label
    }
}
