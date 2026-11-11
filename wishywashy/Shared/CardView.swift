//
//  CardView.swift
//  wishywashy
//

import UIKit

/// Cartoon sticker card: thick ink outline with a hard pink shadow.
final class CardView: UIView {
    var isEmphasized = false { didSet { updateStyle() } }
    /// Overrides the default white / pink fill.
    var fill: UIColor? { didSet { updateStyle() } }

    private let radius: CGFloat

    init(radius: CGFloat = 24) {
        self.radius = radius
        super.init(frame: .zero)
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.borderWidth = 2.5
        layer.shadowOpacity = 1
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 5)
        updateStyle()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: CardView, _) in
            view.updateStyle()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }

    private func updateStyle() {
        backgroundColor = fill ?? (isEmphasized ? Theme.Tone.pink.soft : Theme.card)
        layer.borderColor = Theme.ink.resolvedColor(with: traitCollection).cgColor
        layer.shadowColor = (isEmphasized ? Theme.ink : Theme.pink).resolvedColor(with: traitCollection).cgColor
    }
}

/// Pink-to-lilac hero card with floating bubbles.
final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    private let bubbles = CAShapeLayer()

    init(radius: CGFloat = 28) {
        super.init(frame: .zero)
        let gradient = layer as! CAGradientLayer
        gradient.colors = [Theme.gradientStart.cgColor, Theme.gradientEnd.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.borderWidth = 2.5
        layer.shadowColor = Theme.gradientEnd.cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 5)

        bubbles.fillColor = UIColor.white.withAlphaComponent(0.22).cgColor
        layer.addSublayer(bubbles)
        updateBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: GradientView, _) in
            view.updateBorder()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        let path = UIBezierPath()
        // (center x fraction, center y fraction, radius) – all kept inside the card
        for (x, y, r) in [(0.62, 0.22, 16.0), (0.74, 0.62, 10.0), (0.9, 0.3, 9.0)] {
            path.append(UIBezierPath(arcCenter: CGPoint(x: w * x, y: h * y), radius: min(r, h / 2 - 4),
                                     startAngle: 0, endAngle: .pi * 2, clockwise: true))
        }
        bubbles.path = path.cgPath
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    private func updateBorder() {
        layer.borderColor = Theme.ink.resolvedColor(with: traitCollection).cgColor
    }
}

/// Circle holding an SF Symbol on a pastel background.
final class IconBubble: UIView {
    private let imageView = UIImageView()

    init(size: CGFloat = 48, symbolSize: CGFloat = 22) {
        super.init(frame: .zero)
        layer.cornerRadius = size / 2
        layer.borderWidth = 2.5
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        updateBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: IconBubble, _) in
            view.updateBorder()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(symbol: String, tone: Theme.Tone) {
        imageView.image = UIImage(systemName: symbol)
        imageView.tintColor = tone.tint
        backgroundColor = tone.soft
    }

    private func updateBorder() {
        layer.borderColor = Theme.ink.resolvedColor(with: traitCollection).cgColor
    }
}

/// Rounded progress pill with an ink outline.
final class ProgressBarView: UIView {
    var progress: CGFloat = 0 { didSet { setNeedsLayout() } }

    private let fillView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Tone.pink.soft
        layer.borderWidth = 2.5
        fillView.backgroundColor = Theme.pink
        addSubview(fillView)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 16).isActive = true
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ProgressBarView, _) in
            view.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        layer.borderColor = Theme.ink.resolvedColor(with: traitCollection).cgColor
        let width = bounds.width * min(max(progress, 0), 1)
        fillView.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        fillView.layer.cornerRadius = bounds.height / 2
        fillView.layer.borderWidth = progress > 0 ? 2.5 : 0
        fillView.layer.borderColor = layer.borderColor
    }
}
