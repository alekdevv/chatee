//
//  AppDelegate.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    private let appCoordinator = AppCoordinator()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        appStartup()
        
        return true
    }
    
    private func appStartup() {
        self.appCoordinator.start()
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = self.appCoordinator.viewController
        self.window?.makeKeyAndVisible()
    }

}
