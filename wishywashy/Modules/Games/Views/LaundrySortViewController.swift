//
//  LaundrySortViewController.swift
//  wishywashy
//
//  Tap the right basket for the lowest piece of laundry before it hits the bottom.
//  Built on GameplayKit: a state machine for the phases, entities and components for the garments,
//  shuffled distributions for fair spawns and a rule system that adapts the pace to your streaks.
//

import GameplayKit
import UIKit

final class LaundrySortViewController: UIViewController {

    private enum Kind: CaseIterable {
        case lights, darks, colors

        var title: String {
            switch self {
            case .lights: "Lights"
            case .darks: "Darks"
            case .colors: "Colors"
            }
        }

        var emoji: String {
            switch self {
            case .lights: "☁️"
            case .darks: "🌙"
            case .colors: "🌈"
            }
        }

        func makeFabric() -> UIColor {
            switch self {
            case .lights: return .white
            case .darks: return UIColor(hex: 0x2B2342)
            case .colors:
                let palette: [UInt32] = [0xFF6FB0, 0x4FB6FF, 0x3FD9A4, 0xFFA45C, 0xA98BFF]
                return UIColor(hex: palette.randomElement() ?? 0xFF6FB0)
            }
        }
    }

    private final class GarmentEntity: GKEntity {
        let kind: Kind
        let view: UIView
        let fall: FallComponent

        var y: CGFloat { fall.y }

        init(kind: Kind, view: UIView, x: CGFloat, y: CGFloat) {
            self.kind = kind
            self.view = view
            fall = FallComponent(x: x, y: y)
            super.init()
            addComponent(ViewComponent(view: view))
            addComponent(fall)
            addComponent(ScoreValueComponent(points: 1))
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }

    private let garmentSize: CGFloat = 72
    private let startingLives = 3

    private lazy var phase = GamePhase(onStart: { [weak self] in self?.beginRound() },
                                       onOver: { [weak self] in self?.endRound() })
    private let registry = EntityRegistry<GarmentEntity>(updating: [FallComponent.self])
    private let kindPicker = ShuffledPicker(Kind.allCases)
    private var lanePicker: ShuffledPicker<Int>?
    private var lanePickerCount = 0
    private let advisor = DifficultyAdvisor()
    private var outcomes = OutcomeTracker()
    private var difficulty = DifficultyProfile.neutral
    private var peakIntensity: Float = 0.5
    private var score = 0
    private var lives = 3
    private var sinceSpawn: Double = 0

    private lazy var loop = GameLoop { [weak self] dt in self?.update(dt) }
    private let scorePill = StatPill(prefix: "🧺")
    private let livesPill = StatPill(prefix: "")
    private let playfield = PlayfieldView(tone: .lilac)
    private let overlay = GameOverlayView()
    private var baskets: [(kind: Kind, view: CardView)] = []
    private let success = UINotificationFeedbackGenerator()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Laundry Sort"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = Theme.background

        let hud = UIStackView(arrangedSubviews: [scorePill, livesPill])
        hud.distribution = .fillEqually
        hud.spacing = 12

        let basketRow = UIStackView()
        basketRow.spacing = 12
        basketRow.distribution = .fillEqually
        for kind in Kind.allCases {
            let basket = makeBasket(kind)
            baskets.append((kind, basket))
            basketRow.addArrangedSubview(basket)
        }

        [hud, playfield, basketRow, overlay].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            hud.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            hud.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hud.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            playfield.topAnchor.constraint(equalTo: hud.bottomAnchor, constant: 16),
            playfield.leadingAnchor.constraint(equalTo: hud.leadingAnchor),
            playfield.trailingAnchor.constraint(equalTo: hud.trailingAnchor),

            basketRow.topAnchor.constraint(equalTo: playfield.bottomAnchor, constant: 16),
            basketRow.leadingAnchor.constraint(equalTo: hud.leadingAnchor),
            basketRow.trailingAnchor.constraint(equalTo: hud.trailingAnchor),
            basketRow.heightAnchor.constraint(equalToConstant: 92),
            basketRow.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateHUD()
        overlay.onButtonTap = { [weak self] in self?.startGame() }
        overlay.show(emoji: "🧺", title: "Laundry Sort",
                     message: "Tap the right basket for the lowest item before it hits the bottom.\nLights, darks or colors?\nYou have 3 lives.",
                     buttonTitle: "Start")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        loop.stop()
    }

    private func makeBasket(_ kind: Kind) -> CardView {
        let card = CardView(radius: 22)
        let emoji = UILabel()
        emoji.text = kind.emoji
        emoji.font = .systemFont(ofSize: 32)
        emoji.textAlignment = .center
        let title = UILabel()
        title.text = kind.title
        title.font = Theme.font(16, .heavy)
        title.textColor = Theme.ink
        title.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [emoji, title])
        stack.axis = .vertical
        stack.spacing = 2
        stack.isUserInteractionEnabled = false
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(basketTapped(_:)))
        card.addGestureRecognizer(tap)
        return card
    }

    // MARK: - Game flow
    func startGame() { phase.start() }

    private func beginRound() {
        view.layoutIfNeeded()
        registry.entities.forEach { $0.view.removeFromSuperview() }
        registry.removeAll()
        outcomes.reset()
        difficulty = .neutral
        peakIntensity = 0.5
        score = 0
        lives = startingLives
        sinceSpawn = 10
        updateHUD()
        overlay.hide()
        success.prepare()
        loop.start()
    }

    func finishGame() {
        guard phase.isPlaying else { return }
        phase.finish()
    }

    private func endRound() {
        loop.stop()
        registry.entities.forEach { garment in
            UIView.animate(withDuration: 0.25, animations: { garment.view.alpha = 0 },
                           completion: { _ in garment.view.removeFromSuperview() })
        }
        registry.removeAll()
        let isBest = GameScores.recordLaundrySort(score)
        overlay.show(emoji: isBest ? "🏆" : "🧺",
                     title: isBest ? "New best!" : "Out of lives!",
                     message: "You sorted \(score) items.\nPeak pace: \(DifficultyProfile(intensity: peakIntensity).label)\nBest: \(GameScores.laundrySortBest)",
                     buttonTitle: "Play again")
    }

    private func updateHUD() {
        scorePill.setValue("\(score)")
        livesPill.setValue(String(repeating: "❤️", count: max(lives, 0)) + String(repeating: "🤍", count: max(startingLives - lives, 0)))
    }

    private func record(success: Bool) {
        outcomes.record(success)
        difficulty = advisor.profile(for: outcomes)
        peakIntensity = max(peakIntensity, difficulty.intensity)
    }

    private func loseLife() {
        record(success: false)
        lives -= 1
        updateHUD()
        success.notificationOccurred(.error)
        if lives <= 0 { finishGame() }
    }

    // MARK: - Frame update
    private func update(_ dt: CFTimeInterval) {
        guard phase.isPlaying else { return }
        let baseSpeed = CGFloat(min(110 + Double(score) * 5, 280))
        let speed = baseSpeed * difficulty.scale(easy: 0.85, hard: 1.2)

        sinceSpawn += dt
        let interval = max(0.8, 1.5 - Double(score) * 0.03) * Double(difficulty.scale(easy: 1.25, hard: 0.85))
        if sinceSpawn >= interval {
            sinceSpawn = 0
            spawnGarment()
        }

        registry.components(of: FallComponent.self).forEach { $0.speed = speed }
        registry.update(dt)

        // The lowest piece is the one a basket tap will sort, so highlight it
        let lowest = registry.entities.max { $0.y < $1.y }
        for garment in registry.entities {
            let isLowest = garment === lowest
            garment.view.layer.borderWidth = isLowest ? 4 : 2.5
            garment.view.layer.borderColor = (isLowest ? Theme.pink : Theme.ink).resolvedColor(with: traitCollection).cgColor
        }

        let floor = playfield.bounds.height
        let missed = registry.entities.filter { $0.y + garmentSize / 2 >= floor }
        for garment in missed {
            registry.remove(garment)
            drop(garment)
            loseLife()
            if !phase.isPlaying { return }
        }
    }

    private func spawnGarment() {
        let width = playfield.bounds.width
        guard width > garmentSize else { return }
        let kind = kindPicker.next()
        let x = nextSpawnX(width: width)

        let garmentView = UIView(frame: CGRect(x: 0, y: 0, width: garmentSize, height: garmentSize))
        // Fixed pale tile and dark outline so every fabric stays readable in dark mode too
        garmentView.backgroundColor = UIColor(hex: 0xF3EEFF)
        garmentView.layer.cornerRadius = garmentSize / 2
        garmentView.layer.borderWidth = 2.5
        garmentView.isUserInteractionEnabled = false

        let icon = UIImageView(frame: garmentView.bounds)
        icon.image = UIImage(systemName: "tshirt.fill")
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .bold)
        icon.contentMode = .center
        icon.tintColor = kind.makeFabric()
        // Outline keeps the white shirts visible
        icon.layer.shadowColor = UIColor(hex: 0x2B2342).cgColor
        icon.layer.shadowOpacity = 1
        icon.layer.shadowRadius = 1.2
        icon.layer.shadowOffset = .zero
        garmentView.addSubview(icon)

        let startY = -garmentSize / 2
        garmentView.center = CGPoint(x: x, y: startY)
        playfield.addSubview(garmentView)
        registry.add(GarmentEntity(kind: kind, view: garmentView, x: x, y: startY))
    }

    /// Spawns rotate through evenly spaced lanes so garments spread across the whole width
    private func nextSpawnX(width: CGFloat) -> CGFloat {
        let usable = width - 24
        let laneCount = max(2, Int(usable / (garmentSize + 8)))
        if lanePicker == nil || lanePickerCount != laneCount {
            lanePicker = ShuffledPicker(Array(0..<laneCount))
            lanePickerCount = laneCount
        }
        let laneWidth = usable / CGFloat(laneCount)
        let slack = max(0, (laneWidth - garmentSize) / 2)
        let center = 12 + laneWidth * (CGFloat(lanePicker?.next() ?? 0) + 0.5)
        return center + CGFloat.random(in: -slack...slack)
    }

    // MARK: - Sorting
    @objc private func basketTapped(_ gesture: UITapGestureRecognizer) {
        guard let tapped = baskets.first(where: { $0.view === gesture.view }) else { return }
        sort(into: tapped.kind, basket: tapped.view)
    }

    private func sort(into kind: Kind, basket: CardView) {
        guard phase.isPlaying, let garment = registry.entities.max(by: { $0.y < $1.y }) else { return }
        registry.remove(garment)

        if garment.kind == kind {
            record(success: true)
            score += 1
            updateHUD()
            success.notificationOccurred(.success)
            bounce(basket)
            fly(garment, into: basket)
        } else {
            shake(basket)
            drop(garment)
            loseLife()
        }
    }

    private func fly(_ garment: GarmentEntity, into basket: UIView) {
        let start = view.convert(garment.view.center, from: playfield)
        view.addSubview(garment.view)
        garment.view.center = start
        let target = view.convert(CGPoint(x: basket.bounds.midX, y: basket.bounds.midY), from: basket)
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
            garment.view.center = target
            garment.view.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            garment.view.alpha = 0
        }, completion: { _ in garment.view.removeFromSuperview() })
    }

    /// Wrong or missed items fall out of play
    private func drop(_ garment: GarmentEntity) {
        garment.view.layer.borderColor = Theme.Tone.pink.tint.resolvedColor(with: traitCollection).cgColor
        UIView.animate(withDuration: 0.3, animations: {
            garment.view.transform = CGAffineTransform(scaleX: 1.2, y: 1.2).rotated(by: 0.4)
            garment.view.alpha = 0
        }, completion: { _ in garment.view.removeFromSuperview() })
    }

    private func bounce(_ basket: UIView) {
        UIView.animate(withDuration: 0.1, animations: {
            basket.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 0) {
                basket.transform = .identity
            }
        })
    }

    private func shake(_ basket: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, -8, 8, -6, 6, 0]
        animation.duration = 0.3
        basket.layer.add(animation, forKey: "shake")
    }
}

#Preview {
    UINavigationController(rootViewController: LaundrySortViewController())
}
