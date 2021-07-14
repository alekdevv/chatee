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
        let viewController = UIViewController()
        viewController.view.backgroundColor = .yellow
        
        return viewController
    }()
    
    private lazy var tabBarController: UITabBarController = {
        let tabBarController = UITabBarController()
        tabBarController.setViewControllers([], animated: true)
        
        return tabBarController
    }()
    
    private lazy var tabViewController: [UIViewController] = {
        return []
    }()
    
    
    init() {
        
    }
    
}
