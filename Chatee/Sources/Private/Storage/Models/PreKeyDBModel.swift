//
//  PreKeyDBModel.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift

class PreKeyDBModel: Object {
    
    @objc dynamic var keyId = 0
    @objc dynamic var keyData = Data()
    
    override class func primaryKey() -> String? {
        return "keyId"
    }
    
}
