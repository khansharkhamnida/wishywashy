//
//  Theme.swift
//  wishywashy
//
//  Bubblegum modern design system: pastel pinks / blues / lilacs,
//  rounded type, big soft corners and gentle shadows.
//

import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

enum Theme {

    // MARK: - Colors
    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    static let background = dynamic(light: 0xFFF3F9, dark: 0x1C1327)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x2A1E39)
    static let stroke = dynamic(light: 0xFFE3F0, dark: 0x3E2D52)
    static let ink = dynamic(light: 0x3D2A5A, dark: 0xFFF1FA)
    static let inkSoft = dynamic(light: 0x8A77A6, dark: 0xBCA9D6)
    static let pink = dynamic(light: 0xFF6FB0, dark: 0xFF8FC4)

    // Gradient used by hero cards (same in light and dark)
    static let gradientStart = UIColor(hex: 0xFF6FB0)
    static let gradientEnd = UIColor(hex: 0xA98BFF)
    static let shadow = UIColor(hex: 0xFF6FB0)

    /// A pastel pair: `tint` for text/icons, `soft` for the bubble behind them.
    enum Tone {
        case pink, blue, lilac, mint, peach

        var tint: UIColor {
            switch self {
            case .pink: Theme.dynamic(light: 0xE8559A, dark: 0xFF8FC4)
            case .blue: Theme.dynamic(light: 0x2A8FD6, dark: 0x7CCBFF)
            case .lilac: Theme.dynamic(light: 0x8B5FE0, dark: 0xB99BFF)
            case .mint: Theme.dynamic(light: 0x179A72, dark: 0x5FE0B5)
            case .peach: Theme.dynamic(light: 0xD9742F, dark: 0xFFAA7A)
            }
        }

        var soft: UIColor {
            switch self {
            case .pink: Theme.dynamic(light: 0xFFE0EF, dark: 0x4A2A44)
            case .blue: Theme.dynamic(light: 0xDDF1FF, dark: 0x1F3A52)
            case .lilac: Theme.dynamic(light: 0xEDE3FF, dark: 0x3A2D5C)
            case .mint: Theme.dynamic(light: 0xD6F7EB, dark: 0x1B4A3C)
            case .peach: Theme.dynamic(light: 0xFFE9DA, dark: 0x56382A)
            }
        }
    }

    // MARK: - Type
    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    // MARK: - Bars
    static func styleNavigationBar(_ bar: UINavigationBar) {
        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        for appearance in [standard, scrollEdge] {
            appearance.largeTitleTextAttributes = [.font: font(32, .heavy), .foregroundColor: ink]
            appearance.titleTextAttributes = [.font: font(18, .bold), .foregroundColor: ink]
        }
        bar.standardAppearance = standard
        bar.scrollEdgeAppearance = scrollEdge
        bar.tintColor = pink
    }

    static func styleTabBar(_ bar: UITabBar) {
        bar.tintColor = pink
        bar.unselectedItemTintColor = inkSoft
    }
}

extension UIView {
    func pin(to other: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom)
        ])
    }
}
