//
//  SockMatchViewController.swift
//  wishywashy
//
//  Flip cards to find the matching laundry pairs in as few moves as you can.
//  Built on GameplayKit: a state machine for the round flow, a rule system that tunes the peek and
//  flip-back timing to how you are doing, and a seeded random source for the daily challenge.
//

import GameplayKit
import UIKit

final class SockMatchViewController: UIViewController {

    private final class MatchCard: UIView {
        let emoji: String
        private(set) var isFaceUp = false
        var isMatched = false

        private let front = CardView(radius: 18)
        private let back = CardView(radius: 18)
        private let emojiLabel = UILabel()
        private let backIcon = UIImageView(image: UIImage(systemName: "drop.fill"))

        init(emoji: String) {
            self.emoji = emoji
            super.init(frame: .zero)

            emojiLabel.text = emoji
            emojiLabel.font = .systemFont(ofSize: 44)
            emojiLabel.textAlignment = .center
            emojiLabel.adjustsFontSizeToFitWidth = true
            emojiLabel.minimumScaleFactor = 0.5
            front.addSubview(emojiLabel)
            emojiLabel.pin(to: front, insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))

            back.fill = Theme.pink
            backIcon.tintColor = UIColor.white.withAlphaComponent(0.9)
            backIcon.contentMode = .scaleAspectFit
            backIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
            back.addSubview(backIcon)
            backIcon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                backIcon.centerXAnchor.constraint(equalTo: back.centerXAnchor),
                backIcon.centerYAnchor.constraint(equalTo: back.centerYAnchor)
            ])

            [front, back].forEach {
                addSubview($0)
                $0.pin(to: self)
            }
            front.isHidden = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func setFaceUp(_ faceUp: Bool, animated: Bool = true) {
            isFaceUp = faceUp
            let changes = {
                self.front.isHidden = !faceUp
                self.back.isHidden = faceUp
            }
            if animated {
                UIView.transition(with: self, duration: 0.3,
                                  options: [.transitionFlipFromLeft, .allowUserInteraction], animations: changes)
            } else {
                changes()
            }
        }

        func markMatched() {
            isMatched = true
            front.fill = Theme.Tone.mint.soft
            UIView.animate(withDuration: 0.18, animations: {
                self.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
            }, completion: { _ in
                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0) {
                    self.transform = .identity
                }
            })
        }

        func shake() {
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
            animation.values = [0, -6, 6, -4, 4, 0]
            animation.duration = 0.3
            layer.add(animation, forKey: "shake")
        }
    }

    private struct Level {
        let number: Int
        let pairs: Int
        let columns: Int
        /// How long every card is shown face up before the level starts
        let peekSeconds: Double
        let flipBackDelay: Double
        let timeLimit: Int
        let mismatchPenalty: Int

        init(_ number: Int, difficulty: DifficultyProfile = .neutral) {
            self.number = number
            let pairsPerLevel = [3, 4, 6, 8, 10, 12]
            pairs = pairsPerLevel[min(number, pairsPerLevel.count) - 1]
            columns = number == 1 ? 3 : 4
            // A struggling player gets longer to look and more time before a wrong pair flips back
            let peekScale = Double(difficulty.scale(easy: 1.25, hard: 0.75))
            let flipScale = Double(difficulty.scale(easy: 1.2, hard: 0.8))
            peekSeconds = max(0.5, (2.2 - 0.3 * Double(number - 1)) * peekScale)
            flipBackDelay = max(0.3, (0.9 - 0.08 * Double(number - 1)) * flipScale)
            let base = pairs * 7 + 8
            // Past the biggest grid, the clock keeps tightening
            timeLimit = number <= pairsPerLevel.count ? base : max(40, base - 8 * (number - pairsPerLevel.count))
            mismatchPenalty = number >= 3 ? 2 : 0
        }

        var rows: Int { Int((Double(pairs * 2) / Double(columns)).rounded(.up)) }
    }

    private let symbols = ["🧦", "👕", "👖", "🧢", "🧤", "👗", "🩳", "🧣", "👔", "🧥", "👚", "🩱"]

    private enum Mode { case normal, daily }

    private var mode = Mode.normal
    private var level = Level(1)
    private var nextLevelNumber = 1
    private var cards: [MatchCard] = []
    private var firstPick: MatchCard?
    private var pendingPair: (MatchCard, MatchCard)?
    private let advisor = DifficultyAdvisor()
    private var outcomes = OutcomeTracker(window: 10)
    private var difficulty = DifficultyProfile.neutral
    private var moves = 0
    private var matchedPairs = 0
    private var secondsLeft = 0
    private var timer: Timer?
    private lazy var flow = makeFlow()
    private var gridAspect: NSLayoutConstraint?

    private let levelPill = StatPill(prefix: "Lv")
    private let movesPill = StatPill(prefix: "👆")
    private let timePill = StatPill(prefix: "⏱")
    private let gridStack = UIStackView()
    private let hintLabel = UILabel()
    private let overlay = GameOverlayView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sock Match"
        navigationItem.largeTitleDisplayMode = .never
        updateNavigationItems()
        view.backgroundColor = Theme.background

        let hud = UIStackView(arrangedSubviews: [levelPill, movesPill, timePill])
        hud.distribution = .fillEqually
        hud.spacing = 10

        gridStack.axis = .vertical
        gridStack.distribution = .fillEqually

        hintLabel.font = Theme.font(15, .semibold)
        hintLabel.textColor = Theme.inkSoft
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        [hud, gridStack, hintLabel, overlay].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        // The grid's aspect ratio is set per level in buildGrid()
        NSLayoutConstraint.activate([
            hud.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            hud.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hud.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            gridStack.topAnchor.constraint(equalTo: hud.bottomAnchor, constant: 20),
            gridStack.leadingAnchor.constraint(equalTo: hud.leadingAnchor),
            gridStack.trailingAnchor.constraint(equalTo: hud.trailingAnchor),

            hintLabel.topAnchor.constraint(equalTo: gridStack.bottomAnchor, constant: 20),
            hintLabel.leadingAnchor.constraint(equalTo: hud.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: hud.trailingAnchor),
            hintLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        overlay.isHidden = true
        overlay.onButtonTap = { [weak self] in
            guard let self else { return }
            self.startLevel(self.nextLevelNumber)
        }
        startLevel(1)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }

    // MARK: - Setup
    private func updateNavigationItems() {
        let restart = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                self.startLevel(self.level.number)
            })
        let modeMenu = UIBarButtonItem(
            image: UIImage(systemName: mode == .daily ? "calendar.circle.fill" : "calendar"),
            menu: UIMenu(title: "Game mode", children: [
                UIAction(title: "Normal", image: UIImage(systemName: "infinity"),
                         state: mode == .normal ? .on : .off) { [weak self] _ in self?.setMode(.normal) },
                UIAction(title: "Daily challenge", image: UIImage(systemName: "calendar"),
                         state: mode == .daily ? .on : .off) { [weak self] _ in self?.setMode(.daily) }
            ]))
        navigationItem.rightBarButtonItems = [restart, modeMenu]
    }

    private func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        updateNavigationItems()
        startLevel(1)
    }

    private func startLevel(_ number: Int) {
        stopTimer()
        overlay.hide()
        if number == 1 {
            outcomes.reset()
            difficulty = .neutral
        }
        // The daily challenge is the same for everyone, so it never adapts
        level = Level(number, difficulty: mode == .daily ? .neutral : difficulty)
        nextLevelNumber = number
        firstPick = nil
        pendingPair = nil
        moves = 0
        matchedPairs = 0
        secondsLeft = level.timeLimit
        buildGrid()
        updateHUD()
        flow.enter(PeekingState.self)
    }

    private func makeFlow() -> FlowMachine {
        let peeking = PeekingState()
        let awaitingFirst = AwaitingFirstState()
        let resolving = ResolvingState()
        let won = WonState()
        let lost = LostState()

        peeking.onEnter = { [weak self] _ in self?.beginPeek() }
        awaitingFirst.onEnter = { [weak self] previous in
            if previous is PeekingState { self?.endPeek() }
        }
        resolving.onEnter = { [weak self] _ in self?.beginResolving() }
        won.onEnter = { [weak self] _ in self?.showWin() }
        lost.onEnter = { [weak self] _ in self?.showLoss() }
        return FlowMachine(states: [peeking, awaitingFirst, AwaitingSecondState(), resolving, won, lost])
    }

    // Show every card for a moment, then flip them down and start the clock
    private func beginPeek() {
        stopTimer()
        cards.forEach { $0.setFaceUp(true, animated: false) }
        hintLabel.text = "Memorize the cards!"
        flow.after(level.peekSeconds) { [weak self] in
            self?.flow.enter(AwaitingFirstState.self)
        }
    }

    private func endPeek() {
        cards.forEach { $0.setFaceUp(false) }
        updateHint()
        startTimer()
    }

    private func buildGrid() {
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        cards.removeAll()

        let spacing: CGFloat = level.columns == 3 ? 16 : 12
        gridStack.spacing = spacing
        gridAspect?.isActive = false
        let ratio = CGFloat(level.rows) / CGFloat(level.columns) * 1.1
        // High, not required, so tall grids shrink instead of overflowing short screens
        let aspect = gridStack.heightAnchor.constraint(equalTo: gridStack.widthAnchor, multiplier: ratio)
        aspect.priority = .defaultHigh
        aspect.isActive = true
        gridAspect = aspect

        // The daily challenge deals the same deck to everyone, normal games use a fresh source
        let source: GKRandomSource = mode == .daily ? GameRandom.dailySource(level: level.number) : GameRandom.makeSource()
        let chosen = GameRandom.shuffled(symbols, using: source).prefix(level.pairs)
        var deck = GameRandom.shuffled(chosen.flatMap { [$0, $0] }, using: source)
        for _ in 0..<level.rows {
            let row = UIStackView()
            row.spacing = spacing
            row.distribution = .fillEqually
            for _ in 0..<level.columns {
                let card = MatchCard(emoji: deck.removeLast())
                card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:))))
                row.addArrangedSubview(card)
                cards.append(card)
            }
            gridStack.addArrangedSubview(row)
        }
    }

    private func updateHUD() {
        levelPill.setValue("\(level.number)")
        movesPill.setValue("\(moves)")
        timePill.setValue(String(format: "%d:%02d", max(secondsLeft, 0) / 60, max(secondsLeft, 0) % 60))
    }

    private func updateHint() {
        var text = level.mismatchPenalty > 0
            ? "A wrong pair costs \(level.mismatchPenalty) seconds"
            : "Find all \(level.pairs) pairs"
        let best = mode == .daily ? GameScores.sockMatchDailyBest : GameScores.sockMatchBestLevel
        text += mode == .daily ? " · Daily challenge" : ""
        if best > 0 { text += " · Best: level \(best)" }
        hintLabel.text = text
    }

    // MARK: - Timer
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsLeft -= 1
            self.updateHUD()
            if self.secondsLeft <= 0 { self.flow.enter(LostState.self) }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Game flow
    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let card = gesture.view as? MatchCard else { return }
        flip(card)
    }

    private func flip(_ card: MatchCard) {
        guard !card.isFaceUp, !card.isMatched else { return }

        if flow.isIn(AwaitingFirstState.self) {
            card.setFaceUp(true)
            firstPick = card
            flow.enter(AwaitingSecondState.self)
        } else if flow.isIn(AwaitingSecondState.self), let first = firstPick {
            card.setFaceUp(true)
            firstPick = nil
            moves += 1
            updateHUD()

            if first.emoji == card.emoji {
                first.markMatched()
                card.markMatched()
                matchedPairs += 1
                outcomes.record(true)
                flow.enter(matchedPairs == level.pairs ? WonState.self : AwaitingFirstState.self)
            } else {
                outcomes.record(false)
                pendingPair = (first, card)
                flow.enter(ResolvingState.self)
                if level.mismatchPenalty > 0 {
                    secondsLeft = max(0, secondsLeft - level.mismatchPenalty)
                    updateHUD()
                    if secondsLeft == 0 { flow.enter(LostState.self) }
                }
            }
        }
    }

    /// A wrong pair stays visible briefly, then flips back
    private func beginResolving() {
        flow.after(level.flipBackDelay) { [weak self] in
            guard let self, let (first, second) = self.pendingPair else { return }
            self.pendingPair = nil
            first.shake()
            second.shake()
            first.setFaceUp(false)
            second.setFaceUp(false)
            self.flow.enter(AwaitingFirstState.self)
        }
    }

    private func showWin() {
        stopTimer()
        difficulty = advisor.profile(for: outcomes)
        let isBest = mode == .daily
            ? GameScores.recordSockMatchDaily(levelCleared: level.number)
            : GameScores.recordSockMatch(levelCleared: level.number)
        let next = Level(level.number + 1)
        nextLevelNumber = next.number
        let pace = mode == .daily ? "Daily challenge" : "Pace: \(difficulty.label)"
        flow.after(0.6) { [weak self] in
            guard let self else { return }
            self.overlay.show(
                emoji: isBest ? "🏆" : "🎉",
                title: isBest ? "New best!" : "Level \(self.level.number) cleared!",
                message: "Level \(self.level.number) cleared: \(self.moves) moves, \(self.secondsLeft)s left.\nNext: \(next.pairs) pairs in \(next.timeLimit)s\n\(pace)",
                buttonTitle: "Next level")
        }
    }

    private func showLoss() {
        stopTimer()
        difficulty = advisor.profile(for: outcomes)
        nextLevelNumber = level.number
        let best = mode == .daily ? GameScores.sockMatchDailyBest : GameScores.sockMatchBestLevel
        let bestText = best == 0 ? "Clear a level to set a best" : "Best: level \(best)"
        let pace = mode == .daily ? "Daily challenge" : "Pace: \(difficulty.label)"
        flow.after(0.5) { [weak self] in
            guard let self else { return }
            self.overlay.show(
                emoji: "⏰",
                title: "Time's up!",
                message: "You found \(self.matchedPairs) of \(self.level.pairs) pairs on level \(self.level.number).\n\(pace)\n\(bestText)",
                buttonTitle: "Try again")
        }
    }
}

#Preview {
    UINavigationController(rootViewController: SockMatchViewController())
}
