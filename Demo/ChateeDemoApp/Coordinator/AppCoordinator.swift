//
//  AppCoordinator.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import UIKit

protocol AuthFlowControl: AnyObject {
    func login()
    func notLoggedIn()
    func logout()
}

final class AppCoordinator: Coordinator {
    
    var viewController: UIViewController? {
        didSet {
            UIApplication.shared.windows.first?.rootViewController = self.viewController
        }
    }
    
    private lazy var connectViewController: UIViewController = {
        let viewController = ConnectViewController.loadFromNib()
        viewController.coordinator = self
        
        return viewController
    }()
    
    private lazy var loginViewController: UIViewController = {
        let viewController = LoginViewController.loadFromNib()
        viewController.coordinator = self
        
        return viewController
    }()
    
    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.setViewControllers(self.tabViewControllers, animated: true)
        tabBarController.tabBar.tintColor = #colorLiteral(red: 0.4743623725, green: 0.5280066487, blue: 0.3308900392, alpha: 1)
        tabBarController.tabBar.unselectedItemTintColor = #colorLiteral(red: 0.8666666667, green: 0.8980392157, blue: 0.7137254902, alpha: 1)
        
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
//        let alreadyLoggedInTestVar = Bool(ProcessInfo.processInfo.environment["LoggedIn"] ?? "false") ?? false
        self.viewController = self.connectViewController
    }
    
}

extension AppCoordinator: AuthFlowControl {
    
    func notLoggedIn() {
        self.viewController = loginViewController
    }
    
    func login() {
        self.viewController = tabBarController
    }
    
    func logout() {
        
    }
    
}
