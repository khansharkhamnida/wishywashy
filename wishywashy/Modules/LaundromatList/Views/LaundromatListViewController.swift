//
//  LaundromatListViewController.swift
//  wishywashy
//
//  UI only: static sample content.
//

import UIKit

private struct LaundromatSample {
    let name: String
    let address: String
    let distance: String
    let rating: String
    let status: String
    let tone: Theme.Tone
    let isSelected: Bool
    let washersFree: Int
    let dryersFree: Int
}

final class LaundromatListViewController: UIViewController {

    private let laundromats = [
        LaundromatSample(name: "WishyWash Tampines", address: "Blk 4 Tampines Street 11, Singapore",
                         distance: "850 m away", rating: "★ 4.5", status: "Open", tone: .mint, isSelected: true,
                         washersFree: 4, dryersFree: 2),
        LaundromatSample(name: "WishyWash Orchard", address: "Somerset Road, Orchard, Singapore",
                         distance: "2.3 km away", rating: "★ 4.2", status: "Closed", tone: .pink, isSelected: false,
                         washersFree: 0, dryersFree: 0),
        LaundromatSample(name: "WishyWash Jurong East", address: "Jurong Gateway Road, Jurong East, Singapore",
                         distance: "7.8 km away", rating: "No ratings yet", status: "Open", tone: .mint, isSelected: false,
                         washersFree: 6, dryersFree: 3),
        LaundromatSample(name: "WishyWash Bugis", address: "Victoria Street, Bugis, Singapore",
                         distance: "Unknown", rating: "★ 3.8", status: "Hours unknown", tone: .peach, isSelected: false,
                         washersFree: 1, dryersFree: 0)
    ]

    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose Laundromat"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = Theme.background

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.dataSource = self
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 16, right: 0)
        tableView.register(LaundromatCell.self, forCellReuseIdentifier: LaundromatCell.identifier)
        view.addSubview(tableView)
        tableView.pin(to: view)
    }
}

extension LaundromatListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { laundromats.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LaundromatCell.identifier, for: indexPath) as! LaundromatCell
        let item = laundromats[indexPath.row]
        cell.configure(name: item.name, address: item.address, distance: item.distance, rating: item.rating,
                       status: item.status, tone: item.tone, isSelected: item.isSelected,
                       washersFree: item.washersFree, dryersFree: item.dryersFree)
        return cell
    }
}

private final class LaundromatCell: UITableViewCell {
    static let identifier = "LaundromatCell"

    private let card = CardView()
    private let awning = AwningView()
    private let bubble = IconBubble()
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let distanceLabel = UILabel()
    private let ratingLabel = UILabel()
    private let statusBadge = BadgeLabel()
    private let washersBadge = BadgeLabel()
    private let dryersBadge = BadgeLabel()
    private let checkImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        nameLabel.font = Theme.font(18, .bold)
        nameLabel.textColor = Theme.ink
        addressLabel.font = Theme.font(14)
        addressLabel.textColor = Theme.inkSoft
        addressLabel.numberOfLines = 2
        distanceLabel.font = Theme.font(14, .medium)
        distanceLabel.textColor = Theme.inkSoft
        ratingLabel.font = Theme.font(14, .semibold)
        checkImageView.tintColor = Theme.pink
        checkImageView.setContentHuggingPriority(.required, for: .horizontal)
        bubble.configure(symbol: "mappin.and.ellipse", tone: .pink)

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, checkImageView])
        nameRow.spacing = 8
        nameRow.alignment = .center

        let metaRow = UIStackView(arrangedSubviews: [statusBadge, distanceLabel, ratingLabel, UIView()])
        metaRow.spacing = 10
        metaRow.alignment = .center

        let machinesRow = UIStackView(arrangedSubviews: [washersBadge, dryersBadge, UIView()])
        machinesRow.spacing = 8
        machinesRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [nameRow, addressLabel, metaRow, machinesRow])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.setCustomSpacing(10, after: addressLabel)

        let row = UIStackView(arrangedSubviews: [bubble, textStack])
        row.spacing = 14
        row.alignment = .top

        contentView.addSubview(card)
        card.pin(to: contentView, insets: UIEdgeInsets(top: 6, left: 20, bottom: 6, right: 20))
        card.addSubview(awning)
        card.addSubview(row)
        NSLayoutConstraint.activate([
            awning.topAnchor.constraint(equalTo: card.topAnchor),
            awning.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            awning.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])
        row.pin(to: card, insets: UIEdgeInsets(top: AwningView.height + 14, left: 16, bottom: 16, right: 16))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(name: String, address: String, distance: String, rating: String,
                   status: String, tone: Theme.Tone, isSelected: Bool, washersFree: Int, dryersFree: Int) {
        nameLabel.text = name
        addressLabel.text = address
        distanceLabel.text = distance
        ratingLabel.text = rating
        ratingLabel.textColor = rating.hasPrefix("★") ? Theme.Tone.peach.tint : Theme.inkSoft
        statusBadge.configure(text: status, tone: tone)
        washersBadge.configure(text: "\(washersFree) washers free", tone: washersFree > 0 ? .blue : .pink)
        dryersBadge.configure(text: "\(dryersFree) dryers free", tone: dryersFree > 0 ? .lilac : .pink)
        checkImageView.isHidden = !isSelected
        card.isEmphasized = isSelected
    }
}

#Preview {
    UINavigationController(rootViewController: LaundromatListViewController())
}
