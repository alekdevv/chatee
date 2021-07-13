//
//  SignalIdentityDBModel.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift

final class SignalIdentityDBModel: Object {
    
    @objc dynamic var privateKey = Data()
    @objc dynamic var publicKey = Data()
    @objc dynamic var registrationId = 0
    
    override class func primaryKey() -> String? {
        return "registrationId"
    }
    
}
