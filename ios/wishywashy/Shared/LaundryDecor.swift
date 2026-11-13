//
//  LaundryDecor.swift
//  wishywashy
//
//  Cartoon laundromat decorations: a striped shop awning and a washing machine porthole.
//

import UIKit

/// Striped scalloped shop awning, meant to sit along the top edge of a card.
final class AwningView: UIView {
    static let height: CGFloat = 36

    private let stripes = 10

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        contentMode = .redraw
        clipsToBounds = true
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.height).isActive = true
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: AwningView, _) in
            view.setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        let width = bounds.width / CGFloat(stripes)
        let radius = width / 2
        let bodyHeight = bounds.height - radius - 1.5
        let ink = Theme.ink.resolvedColor(with: traitCollection)
        let pink = Theme.pink.resolvedColor(with: traitCollection)
        let white = Theme.card.resolvedColor(with: traitCollection)

        for i in 0..<stripes {
            let x = CGFloat(i) * width
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x + width, y: 0))
            path.addLine(to: CGPoint(x: x + width, y: bodyHeight))
            path.addArc(withCenter: CGPoint(x: x + radius, y: bodyHeight), radius: radius,
                        startAngle: 0, endAngle: .pi, clockwise: true)
            path.close()
            (i % 2 == 0 ? pink : white).setFill()
            path.fill()
            ink.setStroke()
            path.lineWidth = 2.5
            path.stroke()
        }
    }
}

/// Round washing machine door: ring, glass, sloshing water, shine and bobbing bubbles.
final class PortholeView: UIView {
    private let glass = UIView()
    private let water = CAShapeLayer()
    private let shine = UIView()
    private let bubbles = [UIView(), UIView(), UIView()]
    private var tone: Theme.Tone = .blue

    init(size: CGFloat = 88) {
        super.init(frame: .zero)
        backgroundColor = Theme.card
        layer.borderWidth = 3

        glass.clipsToBounds = true
        glass.layer.borderWidth = 2.5
        glass.layer.addSublayer(water)
        addSubview(glass)

        shine.backgroundColor = UIColor.white.withAlphaComponent(0.85)
        glass.addSubview(shine)
        bubbles.forEach {
            $0.backgroundColor = UIColor.white.withAlphaComponent(0.9)
            $0.layer.borderWidth = 1.5
            glass.addSubview($0)
        }

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size)
        ])
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: PortholeView, _) in
            view.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(tone: Theme.Tone) {
        self.tone = tone
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let ink = Theme.ink.resolvedColor(with: traitCollection).cgColor
        layer.cornerRadius = bounds.width / 2
        layer.borderColor = ink

        glass.frame = bounds.insetBy(dx: 10, dy: 10)
        glass.layer.cornerRadius = glass.bounds.width / 2
        glass.layer.borderColor = ink
        glass.backgroundColor = tone.soft

        let w = glass.bounds.width, h = glass.bounds.height
        water.frame = glass.bounds
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: h * 0.5))
        path.addCurve(to: CGPoint(x: w, y: h * 0.5),
                      controlPoint1: CGPoint(x: w * 0.3, y: h * 0.5 - 9),
                      controlPoint2: CGPoint(x: w * 0.7, y: h * 0.5 + 9))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.close()
        water.path = path.cgPath
        water.fillColor = tone.tint.withAlphaComponent(0.45).resolvedColor(with: traitCollection).cgColor

        shine.bounds = CGRect(x: 0, y: 0, width: 16, height: 7)
        shine.layer.cornerRadius = 3.5
        shine.center = CGPoint(x: w * 0.3, y: h * 0.2)
        shine.transform = CGAffineTransform(rotationAngle: -0.6)

        let spots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [(0.3, 0.64, 10), (0.56, 0.76, 7), (0.7, 0.58, 8)]
        for (bubble, spot) in zip(bubbles, spots) {
            bubble.bounds = CGRect(x: 0, y: 0, width: spot.size, height: spot.size)
            bubble.layer.cornerRadius = spot.size / 2
            bubble.layer.borderColor = tone.tint.resolvedColor(with: traitCollection).cgColor
            bubble.center = CGPoint(x: w * spot.x, y: h * spot.y)
        }
    }

    // Bubbles bob while the machine is on screen
    override func didMoveToWindow() {
        super.didMoveToWindow()
        bubbles.forEach { $0.layer.removeAllAnimations(); $0.transform = .identity }
        guard window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
        for (index, bubble) in bubbles.enumerated() {
            UIView.animate(withDuration: 1.2 + Double(index) * 0.3, delay: Double(index) * 0.2,
                           options: [.repeat, .autoreverse, .curveEaseInOut]) {
                bubble.transform = CGAffineTransform(translationX: 0, y: -10)
            }
        }
    }
}
