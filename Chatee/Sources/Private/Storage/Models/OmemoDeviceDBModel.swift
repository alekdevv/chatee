//
//  OmemoDeviceDBModel.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift

class OmemoDeviceDBModel: Object {
    
    @objc dynamic var id = 0
    @objc dynamic var userJid = ""
    
    @objc dynamic var trustLevel = 0
    var trustLevelType: OmemoTrustLevel {
        get {
            return OmemoTrustLevel(rawValue: trustLevel) ?? .untrustedNew
        }
        set {
            trustLevel = newValue.rawValue
        }
    }
    
    override class func primaryKey() -> String? {
        return "id"
    }
    
}

enum OmemoTrustLevel: Int {
    /// new device seen
    case untrustedNew
    /// device manually untrusted
    case untrusted
    /// device trusted on first use
    case trustedTofu
    /// device manually trusted by user
    case trustedUser
    /** If the device has been removed from the server */
    case removed
}
