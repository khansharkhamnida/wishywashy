//
//  GameLoop.swift
//  wishywashy
//
//  Frame timing for the mini games.
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
