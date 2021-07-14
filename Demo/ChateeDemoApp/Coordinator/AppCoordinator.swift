//
//  AppCoordinator.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import UIKit

final class AppCoordinator: Coordinator {
    
    var viewController: UIViewController? {
        return Account.shared.isLoggedIn ? self.tabBarController : self.loginViewController
    }
    
    private lazy var loginViewController: UIViewController = {
        let viewController = LoginViewController()
        viewController.view.backgroundColor = .yellow
        
        return viewController
    }()
    
    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.setViewControllers(self.tabViewControllers, animated: true)
        
        return tabBarController
    }()
    
    private lazy var tabViewControllers: [UIViewController] = {
        let chatsViewController = ChatsViewController()
        let contactsViewController = ContactsViewController()
        let settingsViewController = SettingsViewController()
        
        return [chatsViewController, contactsViewController, settingsViewController]
    }()
    
    
    init() {
        
    }
    
}
