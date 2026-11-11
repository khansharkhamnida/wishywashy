//
//  CycleCell.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 10/11/26.
//

import UIKit

final class CycleCell: UITableViewCell {
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
