//
//  MyLaundryViewController.swift
//  wishywashy
//
//  UI only: static sample content.
//

import UIKit

private struct CycleSample {
    let icon: String
    let title: String
    let place: String
    let status: String
    let tone: Theme.Tone
    let progress: CGFloat?
    let timeText: String
}

final class MyLaundryViewController: UIViewController {

    private let sections: [(title: String, cycles: [CycleSample])] = [
        ("Running now", [
            CycleSample(icon: "washer", title: "Washer W02", place: "WishyWash Tampines", status: "Washing",
                        tone: .mint, progress: 0.5, timeText: "18 min left"),
            CycleSample(icon: "dryer", title: "Dryer D03", place: "WishyWash Tampines", status: "Drying",
                        tone: .blue, progress: 0.8, timeText: "8 min left")
        ]),
        ("Up next", [
            CycleSample(icon: "dryer", title: "Dryer D01", place: "WishyWash Tampines", status: "Booked",
                        tone: .lilac, progress: nil, timeText: "Starts in 2 h 5 min")
        ])
    ]

    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Laundry"
        view.backgroundColor = Theme.background

        let summary = GradientView()
        let summaryIcon = UIImageView(image: UIImage(systemName: "washer.fill"))
        summaryIcon.tintColor = UIColor.white.withAlphaComponent(0.9)
        summaryIcon.contentMode = .scaleAspectFit
        summaryIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        summaryIcon.setContentHuggingPriority(.required, for: .horizontal)

        let summaryTitle = UILabel()
        summaryTitle.text = "2 cycles running"
        summaryTitle.font = Theme.font(24, .heavy)
        summaryTitle.textColor = .white
        let summarySubtitle = UILabel()
        summarySubtitle.text = "1 up next · fresh clothes soon ✨"
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
        tableView.allowsSelection = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        tableView.register(CycleCell.self, forCellReuseIdentifier: CycleCell.identifier)

        [summary, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            summary.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            summary.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            summary.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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

private final class CycleCell: UITableViewCell {
    static let identifier = "CycleCell"

    private let card = CardView()
    private let bubble = IconBubble()
    private let titleLabel = UILabel()
    private let placeLabel = UILabel()
    private let badge = BadgeLabel()
    private let progressBar = ProgressBarView()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        titleLabel.font = Theme.font(18, .bold)
        titleLabel.textColor = Theme.ink
        placeLabel.font = Theme.font(14)
        placeLabel.textColor = Theme.inkSoft
        timeLabel.font = Theme.font(14, .semibold)
        timeLabel.textColor = Theme.pink

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, placeLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let topRow = UIStackView(arrangedSubviews: [bubble, titleStack, badge])
        topRow.spacing = 12
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, progressBar, timeLabel])
        stack.axis = .vertical
        stack.spacing = 12

        contentView.addSubview(card)
        card.pin(to: contentView, insets: UIEdgeInsets(top: 6, left: 20, bottom: 6, right: 20))
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(icon: String, title: String, place: String, status: String,
                   tone: Theme.Tone, progress: CGFloat?, timeText: String) {
        bubble.configure(symbol: icon, tone: tone)
        titleLabel.text = title
        placeLabel.text = place
        badge.configure(text: status, tone: tone)
        progressBar.isHidden = progress == nil
        progressBar.progress = progress ?? 0
        timeLabel.text = timeText
    }
}

#Preview {
    UINavigationController(rootViewController: MyLaundryViewController())
}
