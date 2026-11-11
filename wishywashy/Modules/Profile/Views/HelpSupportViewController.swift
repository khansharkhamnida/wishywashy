//
//  HelpSupportViewController.swift
//  wishywashy
//

import UIKit

final class HelpSupportViewController: ProfilePageViewController {

    private let supportEmail = "support@example.com"

    private let faqs: [(question: String, answer: String)] = [
        ("How do I change laundromat?",
         "Tap Change location on Home and pick a laundromat from the list. Home updates straight away."),
        ("What do the machine statuses mean?",
         "Each machine shows if it is available, in use, reserved or out of order. Busy machines show when they will be free."),
        ("Where are my past bookings?",
         "Open the Bookings tab and switch to Past. Cycles running right now are on My Laundry."),
        ("What are the mini games?",
         "Open My Laundry and tap Play while you wait. Your best scores are saved on this device.")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Help & Support"
        navigationItem.largeTitleDisplayMode = .never

        var content: [UIView] = [ProfileUI.sectionTitle("Frequently asked")]
        content += faqs.map(makeFAQCard)
        content.append(ProfileUI.sectionTitle("Contact us"))
        content.append(ProfileUI.card(rows: [
            ProfileRowView(title: "Email support", subtitle: supportEmail, symbol: "envelope.fill", tone: .pink,
                           accessory: ProfileUI.chevron(), onTap: { [weak self] in self?.email(subject: "Help with WishyWash") }),
            ProfileRowView(title: "Report a problem", symbol: "exclamationmark.bubble.fill", tone: .peach,
                           accessory: ProfileUI.chevron(), onTap: { [weak self] in self?.email(subject: "Problem report") })
        ]))
        content.append(ProfileUI.caption(versionText()))
        setContent(content)
    }

    private func makeFAQCard(_ faq: (question: String, answer: String)) -> UIView {
        let question = UILabel()
        question.text = faq.question
        question.font = Theme.font(17, .bold)
        question.textColor = Theme.ink
        question.numberOfLines = 0

        let answer = UILabel()
        answer.text = faq.answer
        answer.font = Theme.font(15, .medium)
        answer.textColor = Theme.inkSoft
        answer.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [question, answer])
        stack.axis = .vertical
        stack.spacing = 6

        let card = CardView()
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        return card
    }

    private func email(subject: String) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    private func versionText() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "WishyWash version \(version)"
    }
}

#Preview {
    UINavigationController(rootViewController: HelpSupportViewController())
}
