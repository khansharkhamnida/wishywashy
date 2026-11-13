//
//  GameRandom.swift
//  wishywashy
//
//  GameplayKit randomness: fair picks, bell-curve ranges and seeded daily decks.
//

import CoreGraphics
import GameplayKit

/// Cycles through every item before repeating one, so streaks never get long.
final class ShuffledPicker<Element> {
    private let items: [Element]
    private let distribution: GKShuffledDistribution

    init(_ items: [Element]) {
        precondition(!items.isEmpty, "ShuffledPicker needs at least one item")
        self.items = items
        distribution = GKShuffledDistribution(randomSource: GameRandom.makeSource(),
                                              lowestValue: 0, highestValue: max(items.count - 1, 0))
    }

    func next() -> Element { items[min(distribution.nextInt(), items.count - 1)] }
}

/// Whole numbers clustered around the middle of a range, clamped to its ends.
final class GaussianRange {
    private let distribution: GKGaussianDistribution

    init(_ range: ClosedRange<Int>) {
        distribution = GKGaussianDistribution(randomSource: GameRandom.makeSource(),
                                              lowestValue: range.lowerBound, highestValue: range.upperBound)
    }

    func next() -> CGFloat { CGFloat(distribution.nextInt()) }
}

enum GameRandom {
    /// A fresh, well-mixed source. ARC4 output is predictable until its first values are dropped.
    static func makeSource() -> GKARC4RandomSource {
        let source = GKARC4RandomSource()
        source.dropValues(1024)
        return source
    }

    /// Same value for everyone on the same calendar day, e.g. 20261106.
    static func dailySeed(for date: Date = Date(), calendar: Calendar = .current) -> UInt64 {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return UInt64(year * 10_000 + month * 100 + day)
    }

    /// A reproducible source for one level of the daily challenge.
    static func dailySource(level: Int, date: Date = Date(), calendar: Calendar = .current) -> GKMersenneTwisterRandomSource {
        GKMersenneTwisterRandomSource(seed: dailySeed(for: date, calendar: calendar) &* 100 &+ UInt64(level))
    }

    static func shuffled<T>(_ items: [T], using source: GKRandomSource) -> [T] {
        source.arrayByShufflingObjects(in: items) as? [T] ?? items
    }
}
