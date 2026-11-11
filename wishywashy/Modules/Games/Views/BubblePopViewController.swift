//
//  BubblePopViewController.swift
//  wishywashy
//
//  Pop the bubbles before they float away. Small bubbles are worth more.
//  Built on GameplayKit: a state machine for the phases, entities and components for the bubbles,
//  agents with separate and wander goals for their drift, distributions for fair spawns and a
//  rule system that adapts the pace to how well you are doing.
//

import GameplayKit
import UIKit

final class BubblePopViewController: UIViewController {

    private final class BubbleEntity: GKEntity {
        let view: UIView
        let radius: CGFloat
        let points: Int
        let tone: Theme.Tone
        let agent = GKAgent2D()
        let wander = GKGoal(toWander: 25)

        init(view: UIView, position: CGPoint, radius: CGFloat, points: Int,
             tone: Theme.Tone, riseSpeed: CGFloat, horizontalBounds: ClosedRange<CGFloat>) {
            self.view = view
            self.radius = radius
            self.points = points
            self.tone = tone
            super.init()

            let viewComponent = ViewComponent(view: view)
            viewComponent.horizontalBounds = horizontalBounds
            agent.delegate = viewComponent
            agent.position = SIMD2(Float(position.x), Float(position.y))
            agent.radius = Float(radius)
            agent.mass = 0.5
            agent.maxSpeed = 45
            agent.maxAcceleration = 90

            addComponent(viewComponent)
            addComponent(RiseComponent(speed: riseSpeed))
            addComponent(agent)
            addComponent(ScoreValueComponent(points: points))
            addComponent(ToneComponent(tone: tone))
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }

    private let duration: Double = 30
    private lazy var phase = GamePhase(onStart: { [weak self] in self?.beginRound() },
                                       onOver: { [weak self] in self?.endRound() })
    // Rise first, then the agents steer and the view follows
    private let registry = EntityRegistry<BubbleEntity>(updating: [RiseComponent.self, GKAgent2D.self])
    private let tonePicker = ShuffledPicker([Theme.Tone.pink, .blue, .lilac, .mint, .peach])
    private let lanePicker = ShuffledPicker(Array(0..<5))
    private let sizeRange = GaussianRange(46...86)
    private let speedJitter = GaussianRange(0...40)
    private let advisor = DifficultyAdvisor()
    private var outcomes = OutcomeTracker()
    private var difficulty = DifficultyProfile.neutral
    private var peakIntensity: Float = 0.5
    private var score = 0
    private var popped = 0
    private var elapsed: Double = 0
    private var sinceSpawn: Double = 0

    private lazy var loop = GameLoop { [weak self] dt in self?.update(dt) }
    private let scorePill = StatPill(prefix: "⭐")
    private let timePill = StatPill(prefix: "⏱")
    private let playfield = PlayfieldView(tone: .blue)
    private let overlay = GameOverlayView()
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Bubble Pop"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = Theme.background

        scorePill.setValue("0")
        timePill.setValue("\(Int(duration))s")

        let hud = UIStackView(arrangedSubviews: [scorePill, timePill])
        hud.distribution = .fillEqually
        hud.spacing = 12

        playfield.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))

        [hud, playfield, overlay].forEach {
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
            playfield.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        overlay.onButtonTap = { [weak self] in self?.startGame() }
        overlay.show(emoji: "🫧", title: "Bubble Pop",
                     message: "Pop as many bubbles as you can in \(Int(duration)) seconds.\nSmall bubbles are worth more!",
                     buttonTitle: "Start")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        loop.stop()
    }

    // MARK: - Game flow
    func startGame() { phase.start() }

    private func beginRound() {
        view.layoutIfNeeded()
        clearBubbles()
        outcomes.reset()
        difficulty = .neutral
        peakIntensity = 0.5
        score = 0
        popped = 0
        elapsed = 0
        sinceSpawn = 0
        scorePill.setValue("0")
        timePill.setValue("\(Int(duration))s")
        overlay.hide()
        haptic.prepare()
        loop.start()
    }

    func finishGame() {
        guard phase.isPlaying else { return }
        phase.finish()
    }

    private func endRound() {
        loop.stop()
        clearBubbles(animated: true)
        let isBest = GameScores.recordBubblePop(score)
        let best = GameScores.bubblePopBest
        overlay.show(emoji: isBest ? "🏆" : "🫧",
                     title: isBest ? "New best!" : "Time's up!",
                     message: "You popped \(popped) bubbles for \(score) points.\nPeak pace: \(DifficultyProfile(intensity: peakIntensity).label)\nBest: \(best)",
                     buttonTitle: "Play again")
    }

    private func clearBubbles(animated: Bool = false) {
        for bubble in registry.entities {
            if animated {
                UIView.animate(withDuration: 0.25, animations: { bubble.view.alpha = 0 },
                               completion: { _ in bubble.view.removeFromSuperview() })
            } else {
                bubble.view.removeFromSuperview()
            }
        }
        registry.removeAll()
    }

    // MARK: - Frame update
    private func update(_ dt: CFTimeInterval) {
        guard phase.isPlaying else { return }
        elapsed += dt
        let remaining = max(0, duration - elapsed)
        timePill.setValue("\(Int(ceil(remaining)))s")

        sinceSpawn += dt
        let interval = max(0.28, 0.75 - elapsed * 0.014) * Double(difficulty.scale(easy: 1.3, hard: 0.75))
        if sinceSpawn >= interval {
            sinceSpawn = 0
            spawnBubble()
        }

        registry.update(dt)

        // Bubbles that float off the top just escape, there is no score penalty
        let escaped = registry.entities.filter { CGFloat($0.agent.position.y) + $0.radius < 0 }
        for bubble in escaped {
            registry.remove(bubble)
            bubble.view.removeFromSuperview()
            record(success: false)
        }
        if !escaped.isEmpty { refreshBehaviors() }

        if remaining <= 0 { finishGame() }
    }

    private func spawnBubble() {
        let width = playfield.bounds.width
        guard width > 0 else { return }
        let tone = tonePicker.next()
        let size = sizeRange.next()
        let radius = size / 2
        let laneWidth = width / 5
        let laneCenter = laneWidth * (CGFloat(lanePicker.next()) + 0.5)
        let minX = radius + 14
        let maxX = max(minX + 1, width - radius - 14)
        let baseX = min(max(laneCenter + CGFloat.random(in: -laneWidth / 4...laneWidth / 4), minX), maxX)

        let bubbleView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        bubbleView.backgroundColor = tone.soft.withAlphaComponent(0.85)
        bubbleView.layer.cornerRadius = radius
        bubbleView.layer.borderWidth = 2.5
        bubbleView.layer.borderColor = tone.tint.resolvedColor(with: traitCollection).cgColor
        bubbleView.isUserInteractionEnabled = false

        let shine = UIView(frame: CGRect(x: size * 0.2, y: size * 0.16, width: size * 0.26, height: size * 0.12))
        shine.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        shine.layer.cornerRadius = size * 0.06
        shine.transform = CGAffineTransform(rotationAngle: -0.6)
        bubbleView.addSubview(shine)

        let startY = playfield.bounds.height + radius
        bubbleView.center = CGPoint(x: baseX, y: startY)
        playfield.addSubview(bubbleView)

        // Small bubbles are worth more and rise faster
        let points = size < 58 ? 3 : (size < 72 ? 2 : 1)
        let baseSpeed = 90 + (86 - size) * 3 + speedJitter.next()
        let speed = baseSpeed * difficulty.scale(easy: 0.85, hard: 1.2)
        registry.add(BubbleEntity(view: bubbleView, position: CGPoint(x: baseX, y: startY), radius: radius,
                                  points: points, tone: tone, riseSpeed: speed,
                                  horizontalBounds: radius...(width - radius)))
        refreshBehaviors()
    }

    /// Every bubble wanders, and steers away from the ones around it so they do not pile up.
    private func refreshBehaviors() {
        let agents = registry.entities.map(\.agent)
        for bubble in registry.entities {
            let behavior = GKBehavior()
            behavior.setWeight(1, for: bubble.wander)
            let others = agents.filter { $0 !== bubble.agent }
            if !others.isEmpty {
                let separate = GKGoal(toSeparateFrom: others, maxDistance: Float(bubble.radius * 2 + 20), maxAngle: .pi)
                behavior.setWeight(6, for: separate)
            }
            bubble.agent.behavior = behavior
        }
    }

    private func record(success: Bool) {
        outcomes.record(success)
        difficulty = advisor.profile(for: outcomes)
        peakIntensity = max(peakIntensity, difficulty.intensity)
    }

    // MARK: - Popping
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard phase.isPlaying else { return }
        let point = gesture.location(in: playfield)

        func distance(_ bubble: BubbleEntity) -> CGFloat {
            hypot(bubble.view.center.x - point.x, bubble.view.center.y - point.y)
        }
        // A little extra reach makes small, fast bubbles playable
        let hit = registry.entities.filter { distance($0) <= $0.radius + 12 }.min { distance($0) < distance($1) }
        guard let bubble = hit else {
            record(success: false)
            return
        }
        pop(bubble)
    }

    private func pop(_ bubble: BubbleEntity) {
        registry.remove(bubble)
        refreshBehaviors()
        record(success: true)
        score += bubble.points
        popped += 1
        scorePill.setValue("\(score)")
        haptic.impactOccurred()

        let center = bubble.view.center
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut, animations: {
            bubble.view.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            bubble.view.alpha = 0
        }, completion: { _ in bubble.view.removeFromSuperview() })
        burst(at: center, tone: bubble.tone, points: bubble.points)
    }

    private func burst(at point: CGPoint, tone: Theme.Tone, points: Int) {
        for index in 0..<6 {
            let dot = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
            dot.center = point
            dot.backgroundColor = tone.tint
            dot.layer.cornerRadius = 4
            playfield.addSubview(dot)
            let angle = CGFloat(index) / 6 * .pi * 2
            UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut, animations: {
                dot.center = CGPoint(x: point.x + cos(angle) * 36, y: point.y + sin(angle) * 36)
                dot.alpha = 0
                dot.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            }, completion: { _ in dot.removeFromSuperview() })
        }

        let label = UILabel()
        label.text = "+\(points)"
        label.font = Theme.font(22, .heavy)
        label.textColor = tone.tint
        label.sizeToFit()
        label.center = point
        playfield.addSubview(label)
        UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseOut, animations: {
            label.center = CGPoint(x: point.x, y: point.y - 44)
            label.alpha = 0
        }, completion: { _ in label.removeFromSuperview() })
    }
}

#Preview {
    UINavigationController(rootViewController: BubblePopViewController())
}
