//
//  ProfileViewController.swift
//  wishywashy
//
//  UI only: static sample content.
//

import UIKit

final class ProfileViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        view.backgroundColor = Theme.background

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.addArrangedSubview(makeHeaderCard())
        contentStack.addArrangedSubview(makeStatsCard())
        contentStack.addArrangedSubview(makeMenuCard())

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

    // MARK: - Sections
    private func makeHeaderCard() -> UIView {
        let card = GradientView()

        let avatar = UILabel()
        avatar.text = "S"
        avatar.font = Theme.font(34, .heavy)
        avatar.textColor = Theme.gradientStart
        avatar.textAlignment = .center
        avatar.backgroundColor = .white
        avatar.layer.cornerRadius = 36
        avatar.clipsToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 72),
            avatar.heightAnchor.constraint(equalToConstant: 72)
        ])

        let name = UILabel()
        name.text = "Shofia"
        name.font = Theme.font(26, .heavy)
        name.textColor = .white

        let email = UILabel()
        email.text = "shofia@example.com"
        email.font = Theme.font(15, .medium)
        email.textColor = UIColor.white.withAlphaComponent(0.9)

        let badge = BadgeLabel()
        badge.text = "✨ Fresh Member"
        badge.textColor = .white
        badge.backgroundColor = UIColor.white.withAlphaComponent(0.25)

        let textStack = UIStackView(arrangedSubviews: [name, email, badge])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.setCustomSpacing(10, after: email)

        let row = UIStackView(arrangedSubviews: [avatar, textStack])
        row.spacing = 16
        row.alignment = .center
        card.addSubview(row)
        row.pin(to: card, insets: UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20))
        return card
    }

    private func makeStatsCard() -> UIView {
        let card = CardView()
        let stats: [(String, String, Theme.Tone)] = [
            ("8", "Bookings", .pink), ("5", "Completed", .mint), ("S$26", "Spent", .lilac)
        ]
        let row = UIStackView(arrangedSubviews: stats.map { makeStat(value: $0.0, title: $0.1, tone: $0.2) })
        row.distribution = .fillEqually
        card.addSubview(row)
        row.pin(to: card, insets: UIEdgeInsets(top: 16, left: 8, bottom: 16, right: 8))
        return card
    }

    private func makeStat(value: String, title: String, tone: Theme.Tone) -> UIView {
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = Theme.font(22, .heavy)
        valueLabel.textColor = tone.tint
        valueLabel.textAlignment = .center
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.font(13, .medium)
        titleLabel.textColor = Theme.inkSoft
        titleLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }

    private func makeMenuCard() -> UIView {
        let card = CardView()
        let items: [(String, String, Theme.Tone)] = [
            ("Payment Methods", "creditcard.fill", .pink),
            ("Saved Laundromats", "heart.fill", .peach),
            ("Notifications", "bell.fill", .blue),
            ("Help & Support", "questionmark.bubble.fill", .lilac)
        ]
        let stack = UIStackView()
        stack.axis = .vertical
        for (index, item) in items.enumerated() {
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = Theme.stroke
                divider.heightAnchor.constraint(equalToConstant: 1.5).isActive = true
                let wrapper = UIView()
                wrapper.addSubview(divider)
                divider.pin(to: wrapper, insets: UIEdgeInsets(top: 0, left: 76, bottom: 0, right: 16))
                stack.addArrangedSubview(wrapper)
            }
            let row = makeRow(title: item.0, symbol: item.1, tone: item.2)
            if item.0 == "Saved Laundromats" {
                row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openLaundromats)))
            }
            stack.addArrangedSubview(row)
        }
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0))
        return card
    }

    // UI-only navigation until a router exists
    @objc private func openLaundromats() {
        let list = LaundromatListViewController()
        list.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(list, animated: true)
    }

    private func makeRow(title: String, symbol: String, tone: Theme.Tone) -> UIView {
        let bubble = IconBubble(size: 44, symbolSize: 18)
        bubble.configure(symbol: symbol, tone: tone)

        let label = UILabel()
        label.text = title
        label.font = Theme.font(17, .semibold)
        label.textColor = Theme.ink

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Theme.inkSoft
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [bubble, label, chevron])
        row.spacing = 16
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        return row
    }
}

#Preview {
    UINavigationController(rootViewController: ProfileViewController())
}
