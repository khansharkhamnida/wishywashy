//
//  NotificationSettingsViewController.swift
//  wishywashy
//

import UIKit

final class NotificationSettingsViewController: ProfilePageViewController {

    private struct Option {
        let key: String
        let title: String
        let subtitle: String
        let symbol: String
        let tone: Theme.Tone
        let defaultValue: Bool
    }

    private let options = [
        Option(key: "notifyCycleDone", title: "Cycle finished", subtitle: "When your wash or dry is done",
               symbol: "washer.fill", tone: .mint, defaultValue: true),
        Option(key: "notifyReminders", title: "Booking reminders", subtitle: "Shortly before a booking starts",
               symbol: "calendar", tone: .blue, defaultValue: true),
        Option(key: "notifyDepartureReminders", title: "Departure reminders", subtitle: "When it's time to leave for a booking",
               symbol: "figure.walk", tone: .pink, defaultValue: true),
        Option(key: "notifyMachineFree", title: "Machine available", subtitle: "When a busy machine frees up",
               symbol: "bell.badge.fill", tone: .lilac, defaultValue: true),
        Option(key: "notifyPromotions", title: "Offers & news", subtitle: "Discounts and new laundromats",
               symbol: "gift.fill", tone: .peach, defaultValue: false)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        navigationItem.largeTitleDisplayMode = .never
        setContent([ProfileUI.card(rows: options.map(makeRow)),
                    ProfileUI.caption("Preferences are saved on this device.")])
    }

    private func makeRow(for option: Option) -> UIView {
        let toggle = UISwitch()
        toggle.onTintColor = Theme.pink
        toggle.isOn = UserDefaults.standard.object(forKey: option.key) as? Bool ?? option.defaultValue
        toggle.addAction(UIAction { action in
            let sender = action.sender as? UISwitch
            UserDefaults.standard.set(sender?.isOn ?? option.defaultValue, forKey: option.key)
        }, for: .valueChanged)
        return ProfileRowView(title: option.title, subtitle: option.subtitle,
                              symbol: option.symbol, tone: option.tone, accessory: toggle)
    }
}

#Preview {
    UINavigationController(rootViewController: NotificationSettingsViewController())
}
