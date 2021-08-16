//
//  AppCoordinator.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import UIKit

protocol AuthFlowControl: AnyObject {
    func login()
    func logout()
}

final class AppCoordinator: Coordinator {
    
    var viewController: UIViewController? {
        didSet {
            UIApplication.shared.windows.first?.rootViewController = self.viewController
        }
    }
    
    private lazy var loginViewController: UIViewController = {
        let viewController = LoginViewController()
        viewController.coordinator = self
        
        return viewController
    }()
    
    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.setViewControllers(self.tabViewControllers, animated: true)
        tabBarController.tabBar.tintColor = .red
        tabBarController.tabBar.barTintColor = .white
        
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
    
    func start() {
        let alreadyLoggedInTestVar = Bool(ProcessInfo.processInfo.environment["LoggedIn"] ?? "false") ?? false
        
        self.viewController = alreadyLoggedInTestVar ? self.tabBarController : Account.shared.isLoggedIn ? self.tabBarController : self.loginViewController
    }
    
}

extension AppCoordinator: AuthFlowControl {
    
    func login() {
        self.viewController = tabBarController
        
    }
    
    func logout() {
        
    }
    
}
