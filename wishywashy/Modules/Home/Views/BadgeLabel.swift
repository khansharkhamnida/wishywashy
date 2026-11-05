//
//  BadgeLabel.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import UIKit
import Foundation

// MARK: - Status badge
final class BadgeLabel: UILabel {
    private let insets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = Theme.font(13, .semibold)
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setAvailable(_ isAvailable: Bool) {
        configure(text: isAvailable ? "Available" : "Occupied", tone: isAvailable ? .mint : .pink)
    }

    func configure(text: String, tone: Theme.Tone) {
        self.text = text
        textColor = tone.tint
        backgroundColor = tone.soft
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        layer.borderWidth = 1.5
        layer.borderColor = (textColor ?? .label).resolvedColor(with: traitCollection).cgColor
    }
}
