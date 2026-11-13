//
//  BookingsViewController.swift
//  wishywashy
//
//  Shows the user's bookings, split into upcoming and past.
//

import UIKit

final class BookingsViewController: UIViewController {

    var presenter: BookingsPresenterProtocol?

    private var bookings: [BookingCardViewModel] = []
    private let emptyLabel = UILabel()

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
        segmentedControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter?.didSelectFilter(self.segmentedControl.selectedSegmentIndex == 0 ? .upcoming : .past)
        }, for: .valueChanged)

        emptyLabel.font = Theme.font(16, .semibold)
        emptyLabel.textColor = Theme.inkSoft
        emptyLabel.textAlignment = .center

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
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

        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }
}

extension BookingsViewController: BookingsViewProtocol {
    func showBookingOptions(bookingId: String, title: String) {
        let sheet = UIAlertController(title: title, message: "It is free to cancel before you check in.", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Check if I can arrive on time", style: .default) { [weak self] _ in
            self?.presenter?.didCheckArrival(id: bookingId)
        })
        sheet.addAction(UIAlertAction(title: "Cancel booking", style: .destructive) { [weak self] _ in
            self?.presenter?.didCancelBooking(id: bookingId)
        })
        sheet.addAction(UIAlertAction(title: "Keep it", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        present(sheet, animated: true)
    }

    func showBookings(_ items: [BookingCardViewModel], emptyMessage: String) {
        bookings = items
        emptyLabel.text = emptyMessage
        tableView.backgroundView = items.isEmpty ? emptyLabel : nil
        tableView.reloadData()
    }
}

extension BookingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = bookings[indexPath.row]
        if item.canCancel { presenter?.didTapBooking(id: item.bookingId) }
    }
}

extension BookingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { bookings.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BookingCell.identifier, for: indexPath) as! BookingCell
        let item = bookings[indexPath.row]
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
    UINavigationController(rootViewController: BookingsRouter.createModule())
}
