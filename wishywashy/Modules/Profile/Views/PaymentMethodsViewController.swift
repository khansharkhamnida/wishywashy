//
//  PaymentMethodsViewController.swift
//  wishywashy
//

import UIKit

final class PaymentMethodsViewController: ProfilePageViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payment Methods"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in
            self?.showAddSheet()
        })
        navigationItem.rightBarButtonItem?.tintColor = Theme.pink
        reload()
    }

    private func reload() {
        let methods = MockPaymentMethods.all
        guard !methods.isEmpty else {
            setContent([ProfileUI.caption("No payment methods yet. Tap + to add one.")])
            return
        }
        let rows = methods.map { method in
            ProfileRowView(title: method.title, subtitle: method.detail,
                           symbol: symbol(for: method.kind), tone: tone(for: method.kind),
                           accessory: method.isDefault ? defaultBadge() : ProfileUI.chevron(),
                           onTap: { [weak self] in self?.showActions(for: method) })
        }
        setContent([ProfileUI.card(rows: rows),
                    ProfileUI.caption("These are sample saved methods. At check-in you choose how to pay: card, PayNow or Apple Pay.")])
    }

    private func showActions(for method: SavedPaymentMethod) {
        let sheet = UIAlertController(title: method.title, message: method.detail, preferredStyle: .actionSheet)
        if !method.isDefault {
            sheet.addAction(UIAlertAction(title: "Set as default", style: .default) { [weak self] _ in
                MockPaymentMethods.setDefault(id: method.id)
                self?.reload()
            })
        }
        sheet.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            MockPaymentMethods.remove(id: method.id)
            self?.reload()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet: sheet)
    }

    private func showAddSheet() {
        let sheet = UIAlertController(title: "Add payment method", message: nil, preferredStyle: .actionSheet)
        let options: [(String, PaymentMethod)] = [("Card", .card), ("E-wallet", .eWallet), ("Apple Pay", .applePay)]
        for (title, kind) in options {
            // One Apple Pay entry is enough
            if kind == .applePay, MockPaymentMethods.all.contains(where: { $0.kind == .applePay }) { continue }
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                MockPaymentMethods.add(kind: kind)
                self?.reload()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet: sheet)
    }

    private func defaultBadge() -> UIView {
        let badge = BadgeLabel()
        badge.configure(text: "Default", tone: .mint)
        return badge
    }

    private func symbol(for kind: PaymentMethod) -> String {
        switch kind {
        case .card: return "creditcard.fill"
        case .eWallet: return "wallet.pass.fill"
        case .applePay: return "applelogo"
        case .payNow: return "qrcode"
        }
    }

    private func tone(for kind: PaymentMethod) -> Theme.Tone {
        switch kind {
        case .card: return .pink
        case .eWallet: return .blue
        case .applePay: return .lilac
        case .payNow: return .peach
        }
    }
}

#Preview {
    UINavigationController(rootViewController: PaymentMethodsViewController())
}
