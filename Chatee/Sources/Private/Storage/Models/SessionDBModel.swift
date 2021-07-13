//
//  SessionDBModel.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift

final class SessionDBModel: Object {
    
    @objc dynamic var name = ""
    @objc dynamic var sessionData = Data()
    @objc dynamic var deviceId = 0

    override static func primaryKey() -> String? {
        return "deviceId"
    }
    
}
