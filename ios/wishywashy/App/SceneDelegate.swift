//
//  SceneDelegate.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var authObserver: NSObjectProtocol?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        guard Services.auth.requiresSignIn else {
            // Sample mode: no login, straight to the tab bar
            window?.rootViewController = MainTabBarController()
            window?.makeKeyAndVisible()
            return
        }

        window?.rootViewController = SplashViewController()
        window?.makeKeyAndVisible()
        authObserver = NotificationCenter.default.addObserver(forName: .authStateDidChange, object: nil,
                                                              queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.showRoot(animated: true) }
        }
        Task {
            _ = await Services.auth.restoreSession()
            showRoot(animated: false)
        }
    }

    /// Live mode: the tab bar when someone is signed in, the login flow when not
    private func showRoot(animated: Bool) {
        guard let window else { return }
        let signedIn = Services.auth.currentUser != nil
        let showsTabBar = window.rootViewController is MainTabBarController
        let showsAuthFlow = window.rootViewController is UINavigationController
        if signedIn ? showsTabBar : showsAuthFlow { return }

        let root: UIViewController = signedIn ? MainTabBarController() : AuthRouter.createModule()
        guard animated else {
            window.rootViewController = root
            return
        }
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = root
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

