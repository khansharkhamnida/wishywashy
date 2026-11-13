
import UIKit

final class LaundromatCell: UICollectionViewCell {
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
    private let noMachineInfoBadge = BadgeLabel()
    private let machinesRow = UIStackView()
    private let checkImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let heartButton = UIButton(type: .system)

    /// Set by the view controller every time the cell is configured
    var onToggleSave: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        
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
        heartButton.tintColor = Theme.pink
        heartButton.setContentHuggingPriority(.required, for: .horizontal)
        heartButton.addAction(UIAction { [weak self] _ in self?.onToggleSave?() }, for: .touchUpInside)
        
        let nameRow = UIStackView(arrangedSubviews: [nameLabel, checkImageView, heartButton])
        nameRow.spacing = 8
        nameRow.alignment = .center
        
        let metaRow = UIStackView(arrangedSubviews: [statusBadge, distanceLabel, ratingLabel, UIView()])
        metaRow.spacing = 10
        metaRow.alignment = .center
        
        noMachineInfoBadge.configure(text: "No live machine info yet", tone: .lilac)
        [washersBadge, dryersBadge, noMachineInfoBadge, UIView()].forEach { machinesRow.addArrangedSubview($0) }
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(name: String, address: String, distance: String, rating: String,
                   status: String, tone: Theme.Tone, isSelected: Bool, isSaved: Bool, showsMachines: Bool, washersFree: Int, dryersFree: Int) {
        nameLabel.text = name
        addressLabel.text = address
        distanceLabel.text = distance
        ratingLabel.text = rating
        ratingLabel.textColor = rating.hasPrefix("★") ? Theme.Tone.peach.tint : Theme.inkSoft
        statusBadge.configure(text: status, tone: tone)
        washersBadge.configure(text: "\(washersFree) washers free", tone: washersFree > 0 ? .blue : .pink)
        dryersBadge.configure(text: "\(dryersFree) dryers free", tone: dryersFree > 0 ? .lilac : .pink)
        washersBadge.isHidden = !showsMachines
        dryersBadge.isHidden = !showsMachines
        noMachineInfoBadge.isHidden = showsMachines
        checkImageView.isHidden = !isSelected
        heartButton.setImage(UIImage(systemName: isSaved ? "heart.fill" : "heart"), for: .normal)
        heartButton.accessibilityLabel = isSaved ? "Remove from saved" : "Save laundromat"
        card.isEmphasized = isSelected
    }
}


