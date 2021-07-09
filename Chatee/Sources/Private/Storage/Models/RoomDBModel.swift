//
//  RoomDBModel.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift

class RoomDBModel: Object {
    
    @objc dynamic var jid = ""
    @objc dynamic var displayName = ""
    @objc dynamic var unreadCount = 0
    
    let memberIDs = List<String>()
    let messages = List<MessageDBModel>()
    
    override static func primaryKey() -> String? {
        return "jid"
    }
    
}
