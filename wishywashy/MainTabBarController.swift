//
//  MainTabBarController.swift
//  wishywashy
//
//  Created by Shofia Ghazali on 3/11/26.
//

import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Theme.styleTabBar(tabBar)
        viewControllers = [
            makeTab(HomeRouter.createModule(), title: "Home", image: "house", selectedImage: "house.fill", largeTitle: false),
            makeTab(BookingsViewController(), title: "Bookings", image: "calendar", selectedImage: "calendar"),
            makeTab(MyLaundryViewController(), title: "My Laundry", image: "washer", selectedImage: "washer.fill"),
            makeTab(ProfileViewController(), title: "Profile", image: "person", selectedImage: "person.fill")
        ]
    }

    private func makeTab(_ viewController: UIViewController, title: String, image: String,
                         selectedImage: String, largeTitle: Bool = true) -> UIViewController {
        viewController.view.backgroundColor = Theme.background
        viewController.tabBarItem = UITabBarItem(title: title,
                                                 image: UIImage(systemName: image),
                                                 selectedImage: UIImage(systemName: selectedImage))
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = largeTitle
        Theme.styleNavigationBar(navigationController.navigationBar)
        return navigationController
    }
}

#Preview {
    MainTabBarController()
}
