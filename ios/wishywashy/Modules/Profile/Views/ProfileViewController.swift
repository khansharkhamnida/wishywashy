//
//  ProfileViewController.swift
//  wishywashy
//
//  Header, stats and menu for the signed-in user.
//

import UIKit

final class ProfileViewController: ProfilePageViewController {

    var presenter: ProfilePresenterProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }

    // MARK: - Sections
    private func makeHeaderCard(_ model: ProfileViewModel) -> UIView {
        let card = GradientView()

        let avatar = UILabel()
        avatar.text = model.initial
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
        name.text = model.name
        name.font = Theme.font(26, .heavy)
        name.textColor = .white

        let email = UILabel()
        email.text = model.email
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

    private func makeStatsCard(_ stats: [ProfileStatViewModel]) -> UIView {
        let card = CardView()
        let row = UIStackView(arrangedSubviews: stats.map { makeStat(value: $0.value, title: $0.title, tone: $0.tone) })
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
        let items: [(title: String, symbol: String, tone: Theme.Tone, item: ProfileMenuItem)] = [
            ("Payment Methods", "creditcard.fill", .pink, .paymentMethods),
            ("Saved Laundromats", "heart.fill", .peach, .savedLaundromats),
            ("Notifications", "bell.fill", .blue, .notifications),
            ("Help & Support", "questionmark.bubble.fill", .lilac, .help)
        ]
        return ProfileUI.card(rows: items.map { entry in
            ProfileRowView(title: entry.title, symbol: entry.symbol, tone: entry.tone,
                           accessory: ProfileUI.chevron(),
                           onTap: { [weak self] in self?.presenter?.didSelectMenuItem(entry.item) })
        })
    }

    private func makeSignOutCard() -> UIView {
        ProfileUI.card(rows: [
            ProfileRowView(title: "Sign Out", symbol: "rectangle.portrait.and.arrow.right", tone: .peach,
                           onTap: { [weak self] in self?.confirmSignOut() })
        ])
    }

    private func confirmSignOut() {
        let alert = UIAlertController(title: "Sign out?",
                                      message: "You can sign back in any time.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            self?.presenter?.didConfirmSignOut()
        })
        present(alert, animated: true)
    }
}

extension ProfileViewController: ProfileViewProtocol {
    func showProfile(_ model: ProfileViewModel) {
        var sections = [makeHeaderCard(model), makeStatsCard(model.stats), makeMenuCard()]
        if model.canSignOut { sections.append(makeSignOutCard()) }
        setContent(sections)
    }
}

#Preview {
    UINavigationController(rootViewController: ProfileRouter.createModule())
}
