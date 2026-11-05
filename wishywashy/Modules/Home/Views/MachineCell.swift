//
//  MachineCell.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import UIKit
import Foundation

// MARK: - Machine cell (a little cartoon washing machine)
final class MachineCell: UICollectionViewCell {
    static let identifier = "MachineCell"

    private let card = CardView()
    private let panel = UIView()
    private let panelDivider = UIView()
    private let knob = UIView()
    private let nameLabel = UILabel()
    private let porthole = PortholeView()
    private let badgeLabel = BadgeLabel()
    private let subtitleLabel = UILabel()
    private let priceLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
        setupLayout()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: MachineCell, _) in
            cell.updateOutlineColors()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupStyle() {
        nameLabel.font = Theme.font(20, .heavy)
        nameLabel.textColor = Theme.ink
        subtitleLabel.font = Theme.font(15, .medium)
        subtitleLabel.textColor = Theme.inkSoft
        subtitleLabel.textAlignment = .center
        priceLabel.font = Theme.font(24, .heavy)
        priceLabel.textColor = Theme.pink
        priceLabel.textAlignment = .center
        detailLabel.font = Theme.font(13, .medium)
        detailLabel.textColor = Theme.inkSoft
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 2

        panel.clipsToBounds = true
        panel.layer.cornerRadius = 22
        panel.layer.cornerCurve = .continuous
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        knob.layer.cornerRadius = 11
        knob.layer.borderWidth = 2.5
        knob.backgroundColor = Theme.card
        let tick = UIView()
        tick.backgroundColor = Theme.pink
        tick.layer.cornerRadius = 1
        tick.translatesAutoresizingMaskIntoConstraints = false
        knob.addSubview(tick)
        NSLayoutConstraint.activate([
            tick.topAnchor.constraint(equalTo: knob.topAnchor, constant: 3),
            tick.centerXAnchor.constraint(equalTo: knob.centerXAnchor),
            tick.widthAnchor.constraint(equalToConstant: 2),
            tick.heightAnchor.constraint(equalToConstant: 6)
        ])
        updateOutlineColors()
    }

    private func updateOutlineColors() {
        let ink = Theme.ink.resolvedColor(with: traitCollection)
        panelDivider.backgroundColor = ink
        knob.layer.borderColor = ink.cgColor
    }

    private func makeDot(_ tone: Theme.Tone) -> UIView {
        let dot = UIView()
        dot.backgroundColor = tone.tint
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8)
        ])
        return dot
    }

    private func setupLayout() {
        let controls = UIStackView(arrangedSubviews: [makeDot(.pink), makeDot(.mint), knob])
        controls.spacing = 6
        controls.alignment = .center
        knob.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            knob.widthAnchor.constraint(equalToConstant: 22),
            knob.heightAnchor.constraint(equalToConstant: 22)
        ])

        [nameLabel, controls, panelDivider].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview($0)
        }
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            nameLabel.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            controls.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            controls.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            panelDivider.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            panelDivider.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            panelDivider.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            panelDivider.heightAnchor.constraint(equalToConstant: 2.5)
        ])

        let body = UIStackView(arrangedSubviews: [porthole, badgeLabel, subtitleLabel, priceLabel, detailLabel])
        body.axis = .vertical
        body.alignment = .center
        body.spacing = 6
        body.setCustomSpacing(10, after: porthole)

        contentView.addSubview(card)
        card.pin(to: contentView)
        [panel, body].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: card.topAnchor),
            panel.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            panel.heightAnchor.constraint(equalToConstant: 46),

            body.topAnchor.constraint(equalTo: panel.bottomAnchor, constant: 14),
            body.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            body.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10)
        ])
    }

    func configure(with model: MachineCardViewModel) {
        let tone: Theme.Tone = model.isAvailable ? .blue : .lilac
        nameLabel.text = model.name
        panel.backgroundColor = tone.soft
        porthole.configure(tone: tone)
        badgeLabel.setAvailable(model.isAvailable)
        subtitleLabel.text = model.subtitle
        priceLabel.text = model.priceText
        priceLabel.isHidden = model.priceText == nil
        detailLabel.text = model.detailText
        detailLabel.isHidden = model.detailText == nil
    }
}
