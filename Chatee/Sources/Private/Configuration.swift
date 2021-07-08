//
//  Configuration.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/8/21.
//

import UIKit

class Configuration {
    
    static let shared = Configuration()
    
    private init() {}
    
    var hostName: String?
    var bareJid: String?
    
    var userJid: String?
    let jidResource = "IOS-\(UIDevice.current.identifierForVendor?.uuidString ?? "/")"
}
