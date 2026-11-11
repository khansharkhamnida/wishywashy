//
//  GamesRouter.swift
//  wishywashy
//
//  Entry point of the Games module. The games are real-time and draw their own screens,
//  so each one is a view controller on top of the shared pieces in Gameplay/ and Support/.
//

import UIKit

enum GamesRouter {
    static func createModule() -> UIViewController {
        let games = GamesViewController()
        games.hidesBottomBarWhenPushed = true
        return games
    }
}
