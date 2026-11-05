//
//  BookingsViewController.swift
//  wishywashy
//
//  UI only: static sample content.
//

import UIKit

private struct BookingSample {
    let icon: String
    let title: String
    let place: String
    let date: String
    let price: String
    let status: String
    let tone: Theme.Tone
}

final class BookingsViewController: UIViewController {

    private let upcoming = [
        BookingSample(icon: "dryer", title: "Dryer D01", place: "WishyWash Tampines", date: "Today · 4:30 PM – 5:10 PM",
                      price: "S$4.00", status: "Confirmed", tone: .blue),
        BookingSample(icon: "washer", title: "Washer W03", place: "WishyWash Tampines", date: "Tomorrow · 10:00 AM – 10:36 AM",
                      price: "S$6.00", status: "Confirmed", tone: .blue),
        BookingSample(icon: "washer", title: "Washer W01", place: "WishyWash Orchard", date: "Sat, 9 Nov · 2:00 PM – 2:36 PM",
                      price: "S$6.00", status: "Pending", tone: .peach)
    ]
    private let past = [
        BookingSample(icon: "washer", title: "Washer W01", place: "WishyWash Tampines", date: "Yesterday · 11:00 AM – 11:36 AM",
                      price: "S$6.00", status: "Completed", tone: .lilac),
        BookingSample(icon: "dryer", title: "Dryer D01", place: "WishyWash Tampines", date: "2 Nov · 3:00 PM – 3:40 PM",
                      price: "S$4.00", status: "Completed", tone: .lilac),
        BookingSample(icon: "washer", title: "Washer W04", place: "WishyWash Tampines", date: "29 Oct · 8:00 PM – 8:30 PM",
                      price: "S$5.00", status: "Cancelled", tone: .pink)
    ]

    private var shown: [BookingSample] { segmentedControl.selectedSegmentIndex == 0 ? upcoming : past }

    private let segmentedControl = UISegmentedControl(items: ["Upcoming", "Past"])
    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Bookings"
        view.backgroundColor = Theme.background

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.selectedSegmentTintColor = Theme.pink
        segmentedControl.backgroundColor = Theme.Tone.pink.soft
        segmentedControl.setTitleTextAttributes([.font: Theme.font(15, .semibold), .foregroundColor: Theme.inkSoft], for: .normal)
        segmentedControl.setTitleTextAttributes([.font: Theme.font(15, .bold), .foregroundColor: Theme.dynamic(light: 0xFFFFFF, dark: 0x1C1327)], for: .selected)
        segmentedControl.addAction(UIAction { [weak self] _ in self?.tableView.reloadData() }, for: .valueChanged)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.dataSource = self
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 16, right: 0)
        tableView.register(BookingCell.self, forCellReuseIdentifier: BookingCell.identifier)

        [segmentedControl, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 40),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension BookingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { shown.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BookingCell.identifier, for: indexPath) as! BookingCell
        let item = shown[indexPath.row]
        cell.configure(icon: item.icon, title: item.title, place: item.place, date: item.date,
                       price: item.price, status: item.status, tone: item.tone)
        return cell
    }
}

private final class BookingCell: UITableViewCell {
    static let identifier = "BookingCell"

    private let card = CardView()
    private let bubble = IconBubble()
    private let titleLabel = UILabel()
    private let placeLabel = UILabel()
    private let badge = BadgeLabel()
    private let dateLabel = UILabel()
    private let priceLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        titleLabel.font = Theme.font(18, .bold)
        titleLabel.textColor = Theme.ink
        placeLabel.font = Theme.font(14)
        placeLabel.textColor = Theme.inkSoft
        dateLabel.font = Theme.font(14, .medium)
        dateLabel.textColor = Theme.inkSoft
        dateLabel.numberOfLines = 0
        priceLabel.font = Theme.font(18, .heavy)
        priceLabel.textColor = Theme.pink
        priceLabel.setContentHuggingPriority(.required, for: .horizontal)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, placeLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let topRow = UIStackView(arrangedSubviews: [bubble, titleStack, badge])
        topRow.spacing = 12
        topRow.alignment = .center

        let clock = UIImageView(image: UIImage(systemName: "clock.fill"))
        clock.tintColor = Theme.pink
        clock.setContentHuggingPriority(.required, for: .horizontal)
        let bottomRow = UIStackView(arrangedSubviews: [clock, dateLabel, priceLabel])
        bottomRow.spacing = 8
        bottomRow.alignment = .center

        let divider = UIView()
        divider.backgroundColor = Theme.stroke
        divider.heightAnchor.constraint(equalToConstant: 1.5).isActive = true

        let stack = UIStackView(arrangedSubviews: [topRow, divider, bottomRow])
        stack.axis = .vertical
        stack.spacing = 12

        contentView.addSubview(card)
        card.pin(to: contentView, insets: UIEdgeInsets(top: 6, left: 20, bottom: 6, right: 20))
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(icon: String, title: String, place: String, date: String, price: String, status: String, tone: Theme.Tone) {
        bubble.configure(symbol: icon, tone: tone)
        titleLabel.text = title
        placeLabel.text = place
        dateLabel.text = date
        priceLabel.text = price
        badge.configure(text: status, tone: tone)
    }
}

#Preview {
    UINavigationController(rootViewController: BookingsViewController())
}
