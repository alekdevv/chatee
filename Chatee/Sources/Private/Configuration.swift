//
//  Configuration.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/8/21.
//

import UIKit
import XMPPFramework

class Configuration {
    
    static let shared = Configuration()
    
    private init() {}
    
    var userJID: XMPPJID?
    var hostName: String?
    var bareJid: String?
    
    var userJid: String?
    let jidResource = "IOS-\(UIDevice.current.identifierForVendor?.uuidString ?? "/")"
    
}
