//
//  GameEntities.swift
//  wishywashy
//
//  GameplayKit entities, components and the registry that updates them every frame.
//

import GameplayKit
import UIKit

/// Owns the on-screen view of an entity and mirrors an agent's position onto it.
final class ViewComponent: GKComponent, GKAgentDelegate {
    let view: UIView
    /// Keeps agent-driven entities inside the play area
    var horizontalBounds: ClosedRange<CGFloat>?

    init(view: UIView) {
        self.view = view
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func agentDidUpdate(_ agent: GKAgent) {
        guard let agent = agent as? GKAgent2D else { return }
        if let bounds = horizontalBounds {
            agent.position.x = Float(min(max(CGFloat(agent.position.x), bounds.lowerBound), bounds.upperBound))
        }
        view.center = CGPoint(x: CGFloat(agent.position.x), y: CGFloat(agent.position.y))
    }
}

final class ScoreValueComponent: GKComponent {
    let points: Int

    init(points: Int) {
        self.points = points
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class ToneComponent: GKComponent {
    let tone: Theme.Tone

    init(tone: Theme.Tone) {
        self.tone = tone
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Floats an agent upwards. The agent's own goals add the sideways drift.
final class RiseComponent: GKComponent {
    var speed: CGFloat

    init(speed: CGFloat) {
        self.speed = speed
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func update(deltaTime seconds: TimeInterval) {
        guard let agent = entity?.component(ofType: GKAgent2D.self) else { return }
        agent.position.y -= Float(speed * CGFloat(seconds))
    }
}

/// Drops a view straight down.
final class FallComponent: GKComponent {
    let x: CGFloat
    var y: CGFloat
    var speed: CGFloat = 0

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func update(deltaTime seconds: TimeInterval) {
        y += speed * CGFloat(seconds)
        entity?.component(ofType: ViewComponent.self)?.view.center = CGPoint(x: x, y: y)
    }
}

/// Keeps a game's entities together with one `GKComponentSystem` per component type.
/// The systems update in the order the component classes are given.
final class EntityRegistry<Entity: GKEntity> {
    private(set) var entities: [Entity] = []
    private let systems: [GKComponentSystem<GKComponent>]

    init(updating componentClasses: [GKComponent.Type]) {
        systems = componentClasses.map { GKComponentSystem<GKComponent>(componentClass: $0) }
    }

    func add(_ entity: Entity) {
        entities.append(entity)
        systems.forEach { $0.addComponent(foundIn: entity) }
    }

    func remove(_ entity: Entity) {
        guard entities.contains(where: { $0 === entity }) else { return }
        entities.removeAll { $0 === entity }
        systems.forEach { $0.removeComponent(foundIn: entity) }
    }

    func removeAll() {
        entities.forEach { entity in systems.forEach { $0.removeComponent(foundIn: entity) } }
        entities.removeAll()
    }

    func update(_ deltaTime: TimeInterval) {
        systems.forEach { $0.update(deltaTime: deltaTime) }
    }

    func components<C: GKComponent>(of type: C.Type) -> [C] {
        entities.compactMap { $0.component(ofType: type) }
    }
}
