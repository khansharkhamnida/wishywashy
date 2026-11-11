//
//  GamePhaseStates.swift
//  wishywashy
//
//  GameplayKit state machines that drive the mini games.
//

import GameplayKit

/// A `GKState` whose behaviour is supplied by closures and an allow-list of next states.
class GameState: GKState {
    var onEnter: ((GKState?) -> Void)?
    var onExit: ((GKState) -> Void)?

    var allowedNext: [AnyClass] { [] }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        allowedNext.contains { ObjectIdentifier($0) == ObjectIdentifier(stateClass) }
    }

    override func didEnter(from previousState: GKState?) { onEnter?(previousState) }
    override func willExit(to nextState: GKState) { onExit?(nextState) }
}

/// State machine that can run delayed work which is dropped once the machine moves on.
final class FlowMachine: GKStateMachine {
    private var generation = 0

    @discardableResult
    override func enter(_ stateClass: AnyClass) -> Bool {
        guard canEnterState(stateClass) else { return false }
        // Bump first so work scheduled from `didEnter` belongs to the new state
        generation += 1
        return super.enter(stateClass)
    }

    func isIn(_ stateClass: AnyClass) -> Bool {
        currentState?.isKind(of: stateClass) ?? false
    }

    /// Runs `work` after `delay`, unless another state was entered in the meantime.
    func after(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        let scheduled = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == scheduled else { return }
            work()
        }
    }
}

// MARK: - Ready / playing / over

final class ReadyState: GameState {
    override var allowedNext: [AnyClass] { [PlayingState.self] }
}

final class PlayingState: GameState {
    override var allowedNext: [AnyClass] { [OverState.self] }
}

final class OverState: GameState {
    override var allowedNext: [AnyClass] { [PlayingState.self] }
}

/// Ready, playing and over, shared by the arcade style games.
final class GamePhase {
    private let machine: FlowMachine

    var isPlaying: Bool { machine.isIn(PlayingState.self) }

    init(onStart: @escaping () -> Void, onOver: @escaping () -> Void) {
        let ready = ReadyState()
        let playing = PlayingState()
        let over = OverState()
        playing.onEnter = { _ in onStart() }
        over.onEnter = { _ in onOver() }
        machine = FlowMachine(states: [ready, playing, over])
        machine.enter(ReadyState.self)
    }

    func start() { machine.enter(PlayingState.self) }
    func finish() { machine.enter(OverState.self) }
}

// MARK: - Sock Match round flow

/// All cards are face up for a moment before the clock starts.
final class PeekingState: GameState {
    override var allowedNext: [AnyClass] { [PeekingState.self, AwaitingFirstState.self] }
}

final class AwaitingFirstState: GameState {
    override var allowedNext: [AnyClass] {
        [AwaitingSecondState.self, PeekingState.self, LostState.self]
    }
}

final class AwaitingSecondState: GameState {
    override var allowedNext: [AnyClass] {
        [AwaitingFirstState.self, ResolvingState.self, WonState.self, PeekingState.self, LostState.self]
    }
}

/// A wrong pair is showing and about to flip back.
final class ResolvingState: GameState {
    override var allowedNext: [AnyClass] {
        [AwaitingFirstState.self, PeekingState.self, LostState.self]
    }
}

final class WonState: GameState {
    override var allowedNext: [AnyClass] { [PeekingState.self] }
}

final class LostState: GameState {
    override var allowedNext: [AnyClass] { [PeekingState.self] }
}
