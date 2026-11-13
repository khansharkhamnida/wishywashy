//
//  DifficultyRules.swift
//  wishywashy
//
//  A GKRuleSystem turns recent results into a difficulty level the games can tune themselves with.
//

import GameplayKit

/// Rolling record of the last few outcomes (hit or miss).
struct OutcomeTracker {
    private(set) var recent: [Bool] = []
    private(set) var streak = 0
    private let window: Int

    init(window: Int = 8) { self.window = window }

    mutating func record(_ success: Bool) {
        recent.append(success)
        if recent.count > window { recent.removeFirst() }
        streak = success ? streak + 1 : 0
    }

    mutating func reset() {
        recent.removeAll()
        streak = 0
    }

    /// Share of successes in the window, neutral until there is enough to judge
    var accuracy: Double {
        guard recent.count >= 3 else { return 0.7 }
        return Double(recent.filter { $0 }.count) / Double(recent.count)
    }

    var recentMisses: Int { recent.suffix(5).filter { !$0 }.count }
}

/// How hard the game should feel right now, from 0 (relaxed) to 1 (intense).
struct DifficultyProfile {
    static let neutral = DifficultyProfile(intensity: 0.5)

    let intensity: Float

    var label: String {
        switch intensity {
        case ..<0.35: "Chill 🌤"
        case ..<0.7: "Steady 🌊"
        default: "Frantic 🔥"
        }
    }

    /// `easy` at intensity 0, `hard` at intensity 1, halfway at neutral.
    func scale(easy: CGFloat, hard: CGFloat) -> CGFloat {
        easy + (hard - easy) * CGFloat(intensity)
    }
}

final class DifficultyAdvisor {
    private static let skilled = "skilled" as NSString
    private static let struggling = "struggling" as NSString

    private enum Key {
        static let accuracy = "accuracy"
        static let streak = "streak"
        static let recentMisses = "recentMisses"
    }

    private let system = GKRuleSystem()

    init() {
        system.add([
            // Long streaks and high accuracy mean the player can take more
            GKRule(blockPredicate: { system in Self.number(Key.streak, in: system) >= 3 },
                   action: { system in
                       let streak = Self.number(Key.streak, in: system)
                       system.assertFact(Self.skilled, grade: Float(min(streak, 10) / 10))
                   }),
            GKRule(blockPredicate: { system in Self.number(Key.accuracy, in: system) > 0.75 },
                   action: { system in
                       let accuracy = Self.number(Key.accuracy, in: system)
                       system.assertFact(Self.skilled, grade: Float((accuracy - 0.75) / 0.25))
                   }),
            // Misses and low accuracy mean ease off
            GKRule(blockPredicate: { system in Self.number(Key.accuracy, in: system) < 0.6 },
                   action: { system in
                       let accuracy = Self.number(Key.accuracy, in: system)
                       system.assertFact(Self.struggling, grade: Float((0.6 - accuracy) / 0.6))
                   }),
            GKRule(blockPredicate: { system in Self.number(Key.recentMisses, in: system) >= 2 },
                   action: { system in
                       let misses = Self.number(Key.recentMisses, in: system)
                       system.assertFact(Self.struggling, grade: Float(min(misses, 4) / 4))
                   })
        ])
    }

    func profile(for tracker: OutcomeTracker) -> DifficultyProfile {
        system.reset()
        system.state[Key.accuracy] = tracker.accuracy
        system.state[Key.streak] = tracker.streak
        system.state[Key.recentMisses] = tracker.recentMisses
        system.evaluate()

        let skilled = min(system.grade(forFact: Self.skilled), 1)
        let struggling = min(system.grade(forFact: Self.struggling), 1)
        return DifficultyProfile(intensity: min(max(0.5 + 0.5 * skilled - 0.5 * struggling, 0), 1))
    }

    private static func number(_ key: String, in system: GKRuleSystem) -> Double {
        (system.state[key] as? NSNumber)?.doubleValue ?? 0
    }
}
