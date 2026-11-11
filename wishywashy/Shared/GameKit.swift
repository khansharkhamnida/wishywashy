//
//  GameKit.swift
//  wishywashy
//
//  Small building blocks shared by the mini games.
//

import UIKit

/// Per-frame update loop. Call `stop()` when leaving the screen.
final class GameLoop {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private let onFrame: (CFTimeInterval) -> Void

    init(onFrame: @escaping (CFTimeInterval) -> Void) { self.onFrame = onFrame }

    func start() {
        stop()
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        // Cap the step so a hiccup never teleports things
        let dt = lastTimestamp == 0 ? 0 : min(link.timestamp - lastTimestamp, 1.0 / 20)
        lastTimestamp = link.timestamp
        onFrame(dt)
    }
}

/// Best scores, stored on the device.
enum GameScores {
    private static let defaults = UserDefaults.standard
    private static let bubblePopKey = "game.bubblePop.best"
    private static let sockMatchKey = "game.sockMatch.bestLevel"
    private static let laundrySortKey = "game.laundrySort.best"

    static var bubblePopBest: Int { defaults.integer(forKey: bubblePopKey) }
    /// Highest Sock Match level cleared, 0 means none yet
    static var sockMatchBestLevel: Int { defaults.integer(forKey: sockMatchKey) }
    static var laundrySortBest: Int { defaults.integer(forKey: laundrySortKey) }

    /// Daily challenge results are kept per calendar day
    private static func sockMatchDailyKey(_ date: Date = Date()) -> String {
        "game.sockMatch.daily.\(GameRandom.dailySeed(for: date))"
    }
    static var sockMatchDailyBest: Int { defaults.integer(forKey: sockMatchDailyKey()) }

    /// Each `record` returns true when the result is a new best.
    @discardableResult static func recordBubblePop(_ score: Int) -> Bool {
        guard score > bubblePopBest else { return false }
        defaults.set(score, forKey: bubblePopKey)
        return true
    }

    @discardableResult static func recordSockMatch(levelCleared: Int) -> Bool {
        guard levelCleared > sockMatchBestLevel else { return false }
        defaults.set(levelCleared, forKey: sockMatchKey)
        return true
    }

    @discardableResult static func recordSockMatchDaily(levelCleared: Int) -> Bool {
        guard levelCleared > sockMatchDailyBest else { return false }
        defaults.set(levelCleared, forKey: sockMatchDailyKey())
        return true
    }

    @discardableResult static func recordLaundrySort(_ score: Int) -> Bool {
        guard score > laundrySortBest else { return false }
        defaults.set(score, forKey: laundrySortKey)
        return true
    }
}

/// Small outlined pill for the score / timer row.
final class StatPill: UIView {
    private let label = UILabel()
    private let prefix: String

    init(prefix: String) {
        self.prefix = prefix
        super.init(frame: .zero)
        backgroundColor = Theme.card
        layer.borderWidth = 2.5
        label.font = Theme.font(17, .heavy)
        label.textColor = Theme.ink
        label.textAlignment = .center
        addSubview(label)
        label.pin(to: self, insets: UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14))
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: StatPill, _) in
            view.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ text: String) {
        label.text = prefix.isEmpty ? text : "\(prefix) \(text)"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        layer.borderColor = Theme.ink.resolvedColor(with: traitCollection).cgColor
    }
}

/// Rounded, outlined play area.
final class PlayfieldView: UIView {
    init(tone: Theme.Tone) {
        super.init(frame: .zero)
        backgroundColor = tone.soft
        layer.cornerRadius = 28
        layer.cornerCurve = .continuous
        layer.borderWidth = 2.5
        clipsToBounds = true
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: PlayfieldView, _) in
            view.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.borderColor = Theme.ink.resolvedColor(with: traitCollection).cgColor
    }
}

/// Emoji on a pastel, outlined circle.
final class EmojiBubble: UIView {
    private let label = UILabel()

    init(size: CGFloat = 56) {
        super.init(frame: .zero)
        layer.cornerRadius = size / 2
        layer.borderWidth = 2.5
        label.font = .systemFont(ofSize: size * 0.5)
        label.textAlignment = .center
        addSubview(label)
        translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: EmojiBubble, _) in
            view.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(emoji: String, tone: Theme.Tone) {
        label.text = emoji
        backgroundColor = tone.soft
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.borderColor = Theme.ink.resolvedColor(with: traitCollection).cgColor
    }
}

/// "Ready" and "game over" card shown over a game.
final class GameOverlayView: UIView {
    var onButtonTap: (() -> Void)?

    private let card = CardView(radius: 28)
    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.background.withAlphaComponent(0.88)

        emojiLabel.font = .systemFont(ofSize: 56)
        emojiLabel.textAlignment = .center
        titleLabel.font = Theme.font(26, .heavy)
        titleLabel.textColor = Theme.ink
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        messageLabel.font = Theme.font(16, .medium)
        messageLabel.textColor = Theme.inkSoft
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = Theme.pink
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 32, bottom: 14, trailing: 32)
        config.background.strokeColor = Theme.ink
        config.background.strokeWidth = 2.5
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Theme.font(18, .heavy)
            return attributes
        }
        button.configuration = config
        button.addAction(UIAction { [weak self] _ in self?.onButtonTap?() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [emojiLabel, titleLabel, messageLabel, button])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(20, after: messageLabel)

        addSubview(card)
        card.addSubview(stack)
        stack.pin(to: card, insets: UIEdgeInsets(top: 28, left: 24, bottom: 28, right: 24))
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(emoji: String, title: String, message: String, buttonTitle: String) {
        emojiLabel.text = emoji
        titleLabel.text = title
        messageLabel.text = message
        button.configuration?.title = buttonTitle
        isHidden = false
        alpha = 0
        UIView.animate(withDuration: 0.25) { self.alpha = 1 }
    }

    func hide() {
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }, completion: { _ in
            self.isHidden = true
        })
    }
}
