//
//  MyLaundryViewController.swift
//  wishywashy
//
//  Live view of running and next cycles.
//

import UIKit

final class MyLaundryViewController: UIViewController {

    var presenter: MyLaundryPresenterProtocol?

    private var sections: [CycleSectionViewModel] = []
    private let summaryTitle = UILabel()
    private let summarySubtitle = UILabel()
    private let emptyLabel = UILabel()
    private var refreshTimer: Timer?

    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Laundry"
        view.backgroundColor = Theme.background
        // Live view only; the full schedule, prices and history live in Bookings
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "All bookings", primaryAction: UIAction { [weak self] _ in
            self?.presenter?.didTapAllBookings()
        })
        navigationItem.rightBarButtonItem?.tintColor = Theme.pink

        let summary = GradientView()
        let summaryIcon = UIImageView(image: UIImage(systemName: "washer.fill"))
        summaryIcon.tintColor = UIColor.white.withAlphaComponent(0.9)
        summaryIcon.contentMode = .scaleAspectFit
        summaryIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        summaryIcon.setContentHuggingPriority(.required, for: .horizontal)

        summaryTitle.font = Theme.font(24, .heavy)
        summaryTitle.textColor = .white
        summarySubtitle.font = Theme.font(15, .medium)
        summarySubtitle.textColor = UIColor.white.withAlphaComponent(0.9)
        let textStack = UIStackView(arrangedSubviews: [summaryTitle, summarySubtitle])
        textStack.axis = .vertical
        textStack.spacing = 4

        let summaryRow = UIStackView(arrangedSubviews: [textStack, summaryIcon])
        summaryRow.alignment = .center
        summaryRow.spacing = 12
        summary.addSubview(summaryRow)
        summaryRow.pin(to: summary, insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        tableView.register(CycleCell.self, forCellReuseIdentifier: CycleCell.identifier)

        emptyLabel.text = "No cycles running or booked"
        emptyLabel.font = Theme.font(16, .semibold)
        emptyLabel.textColor = Theme.inkSoft
        emptyLabel.textAlignment = .center

        let playCard = makePlayCard()

        [summary, playCard, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            summary.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            summary.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            summary.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            playCard.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 16),
            playCard.leadingAnchor.constraint(equalTo: summary.leadingAnchor),
            playCard.trailingAnchor.constraint(equalTo: summary.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: playCard.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
        refreshTimer?.invalidate()
        // Keeps the countdowns and progress bars moving while the screen is visible
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.presenter?.didRequestRefresh()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

extension MyLaundryViewController: MyLaundryViewProtocol {
    func showMessage(_ text: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showReservationOptions(bookingId: String, title: String, canCheckIn: Bool) {
        let message = canCheckIn ? "Check in when you are at the machine. You pay then." : "It is free to cancel before you check in."
        let sheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        if canCheckIn {
            sheet.addAction(UIAlertAction(title: "Check in and start", style: .default) { [weak self] _ in
                self?.presenter?.didCheckIn(bookingId: bookingId)
            })
        }
        sheet.addAction(UIAlertAction(title: "Check if I can arrive on time", style: .default) { [weak self] _ in
            self?.presenter?.didCheckArrival(bookingId: bookingId)
        })
        sheet.addAction(UIAlertAction(title: "Cancel reservation", style: .destructive) { [weak self] _ in
            self?.presenter?.didCancelReservation(bookingId: bookingId)
        })
        sheet.addAction(UIAlertAction(title: "Keep it", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        present(sheet, animated: true)
    }

    func showLaundry(_ model: MyLaundryViewModel) {
        summaryTitle.text = model.summaryTitle
        summarySubtitle.text = model.summarySubtitle
        sections = model.sections
        tableView.backgroundView = model.sections.isEmpty ? emptyLabel : nil
        tableView.reloadData()
    }
}

// MARK: - Play while you wait
extension MyLaundryViewController {
    fileprivate func makePlayCard() -> UIView {
        let card = CardView(radius: 22)

        let bubble = IconBubble(size: 44, symbolSize: 20)
        bubble.configure(symbol: "gamecontroller.fill", tone: .lilac)

        let title = UILabel()
        title.text = "Play while you wait"
        title.font = Theme.font(17, .bold)
        title.textColor = Theme.ink
        let subtitle = UILabel()
        subtitle.text = "3 mini games to pass the time"
        subtitle.font = Theme.font(13, .medium)
        subtitle.textColor = Theme.inkSoft
        let texts = UIStackView(arrangedSubviews: [title, subtitle])
        texts.axis = .vertical
        texts.spacing = 2

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Theme.pink
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [bubble, texts, chevron])
        row.spacing = 12
        row.alignment = .center
        card.addSubview(row)
        row.pin(to: card, insets: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))

        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openGames)))
        return card
    }

    @objc fileprivate func openGames() {
        presenter?.didTapGames()
    }
}

extension MyLaundryViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].cycles.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CycleCell.identifier, for: indexPath) as! CycleCell
        let item = sections[indexPath.section].cycles[indexPath.row]
        cell.configure(icon: item.icon, title: item.title, place: item.place, status: item.status,
                       tone: item.tone, progress: item.progress, timeText: item.timeText)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].cycles[indexPath.row]
        if item.isReserved || item.isScheduled { presenter?.didTapReservation(bookingId: item.bookingId) }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        let label = UILabel()
        label.text = sections[section].title
        label.font = Theme.font(20, .bold)
        label.textColor = Theme.ink
        container.addSubview(label)
        label.pin(to: container, insets: UIEdgeInsets(top: 12, left: 20, bottom: 4, right: 20))
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 44 }
}


#Preview {
    UINavigationController(rootViewController: MyLaundryRouter.createModule())
}
