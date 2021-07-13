//
//  ContactDBModel.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift

final class ContactDBModel: Object {
    
    @objc dynamic var jid = ""
    @objc dynamic var name: String?
    @objc dynamic var avatar: Data?
    
    @objc dynamic var subscription: String = ""
    var subscriptionType: ChateeContactSubscription {
        get {
            return ChateeContactSubscription(rawValue: subscription) ?? .none
        }
        set {
            subscription = newValue.rawValue
        }
    }
    
    override static func primaryKey() -> String? {
        return "jid"
    }
    
}
