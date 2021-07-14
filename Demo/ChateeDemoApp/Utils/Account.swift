//
//  Account.swift
//  ChateeDemoApp
//
//  Created by Nikola Aleksendric on 7/14/21.
//

import Foundation

private let isLoggedInKey = "isLoggedInUserDefaultsKey"

final class Account {
    
    static let shared = Account()
    
    var isLoggedIn: Bool {
        get {
            self.defaults.bool(forKey: isLoggedInKey)
        }
        set {
            self.defaults.setValue(newValue, forKey: isLoggedInKey)
        }
    }
    
    private let defaults = UserDefaults.standard
    
    private init() {}
}
