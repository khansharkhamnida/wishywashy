//
//  NotificationSettingsViewController.swift
//  wishywashy
//

import UIKit

final class NotificationSettingsViewController: ProfilePageViewController {

    private struct Option {
        let preference: NotificationPreference
        let title: String
        let subtitle: String
        let symbol: String
        let tone: Theme.Tone
    }

    private let options = [
        Option(preference: .cycleDone, title: "Cycle finished", subtitle: "When your wash or dry is done",
               symbol: "washer.fill", tone: .mint),
        Option(preference: .reminders, title: "Booking reminders", subtitle: "Shortly before a booking starts",
               symbol: "calendar", tone: .blue),
        Option(preference: .departureReminders, title: "Departure reminders", subtitle: "When it's time to leave for a booking",
               symbol: "figure.walk", tone: .pink),
        Option(preference: .machineFree, title: "Machine available", subtitle: "When a busy machine frees up",
               symbol: "bell.badge.fill", tone: .lilac),
        Option(preference: .promotions, title: "Offers & news", subtitle: "Discounts and new laundromats",
               symbol: "gift.fill", tone: .peach)
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
        toggle.isOn = NotificationPreferences.shared.isOn(option.preference)
        toggle.addAction(UIAction { action in
            let sender = action.sender as? UISwitch
            NotificationPreferences.shared.set(option.preference, on: sender?.isOn ?? option.preference.defaultValue)
        }, for: .valueChanged)
        return ProfileRowView(title: option.title, subtitle: option.subtitle,
                              symbol: option.symbol, tone: option.tone, accessory: toggle)
    }
}

#Preview {
    UINavigationController(rootViewController: NotificationSettingsViewController())
}
