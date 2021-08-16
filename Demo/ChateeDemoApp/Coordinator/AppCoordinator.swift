//
//  AppCoordinator.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import UIKit

final class AppCoordinator: Coordinator {
    
    var viewController: UIViewController? {
        let alreadyLoggedInTestVar = Bool(ProcessInfo.processInfo.environment["LoggedIn"] ?? "false") ?? false
        
        return alreadyLoggedInTestVar ? self.tabBarController : Account.shared.isLoggedIn ? self.tabBarController : self.loginViewController
    }
    
    private lazy var loginViewController: UIViewController = {
        let viewController = LoginViewController()
        
        return viewController
    }()
    
    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.setViewControllers(self.tabViewControllers, animated: true)
        tabBarController.tabBar.tintColor = .red
        
        return tabBarController
    }()
    
    private lazy var tabViewControllers: [UIViewController] = {
        let chatsViewController = ChatsViewController.loadFromNib()
        chatsViewController.tabBarItem = UITabBarItem(title: "Chats", image: UIImage(named: "chats-icon")!, tag: 0)
        
        let contactsViewController = ContactsViewController.loadFromNib()
        contactsViewController.tabBarItem = UITabBarItem(title: "Contacts", image: UIImage(named: "contacts-icon")!, tag: 1)
        
        let settingsViewController = SettingsViewController.loadFromNib()
        settingsViewController.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(named: "settings-icon")!, tag: 2)
        
        return [chatsViewController, contactsViewController, settingsViewController]
    }()
    
}
