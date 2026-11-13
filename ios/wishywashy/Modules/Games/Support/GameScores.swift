//
//  GameScores.swift
//  wishywashy
//
//  Best scores for the mini games, saved on the device.
//

import Foundation

/// Best scores, stored on the device.
enum GameScores {
    private static var store: LocalStore { .shared }
    private static let bubblePopKey = "game.bubblePop.best"
    private static let sockMatchKey = "game.sockMatch.bestLevel"
    private static let laundrySortKey = "game.laundrySort.best"

    static var bubblePopBest: Int { store.int(forKey: bubblePopKey) }
    /// Highest Sock Match level cleared, 0 means none yet
    static var sockMatchBestLevel: Int { store.int(forKey: sockMatchKey) }
    static var laundrySortBest: Int { store.int(forKey: laundrySortKey) }

    /// Daily challenge results are kept per calendar day
    private static func sockMatchDailyKey(_ date: Date = Date()) -> String {
        "game.sockMatch.daily.\(GameRandom.dailySeed(for: date))"
    }
    static var sockMatchDailyBest: Int { store.int(forKey: sockMatchDailyKey()) }

    /// Each `record` returns true when the result is a new best.
    @discardableResult static func recordBubblePop(_ score: Int) -> Bool {
        guard score > bubblePopBest else { return false }
        store.set(score, forKey: bubblePopKey)
        return true
    }

    @discardableResult static func recordSockMatch(levelCleared: Int) -> Bool {
        guard levelCleared > sockMatchBestLevel else { return false }
        store.set(levelCleared, forKey: sockMatchKey)
        return true
    }

    @discardableResult static func recordSockMatchDaily(levelCleared: Int) -> Bool {
        guard levelCleared > sockMatchDailyBest else { return false }
        store.set(levelCleared, forKey: sockMatchDailyKey())
        return true
    }

    @discardableResult static func recordLaundrySort(_ score: Int) -> Bool {
        guard score > laundrySortBest else { return false }
        store.set(score, forKey: laundrySortKey)
        return true
    }
}
