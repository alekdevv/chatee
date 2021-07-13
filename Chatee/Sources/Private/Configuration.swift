//
//  Configuration.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/8/21.
//

import UIKit
import XMPPFramework

public enum EncryptionType: String {
    case none, omemo
}

private let encryptionTypeUserDefaultsKey = "encryptionTypeUserDefaultsKey"

class Configuration {
    
    static let shared = Configuration()
    
    var userJID: XMPPJID?
    var userBareJid: String? {
        return userJID?.bare
    }

    var hostName: String?
    
    // TODO: Enable to add jid resource from client side
    let jidResource = "IOS-\(UIDevice.current.identifierForVendor?.uuidString ?? "/")"

    var encryptionType: EncryptionType {
        set {
            self.defaults.setValue(newValue.rawValue, forKey: encryptionTypeUserDefaultsKey)
        }
        get {
            let stringType = self.defaults.string(forKey:encryptionTypeUserDefaultsKey) ?? ""
            
            return EncryptionType(rawValue: stringType) ?? .none
        }
    }
    
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    
}
