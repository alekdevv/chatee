//
//  MessageDBModel.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift

class MessageDBModel: Object {
    
    @objc dynamic var id = ""
    @objc dynamic var room: RoomDBModel?
    @objc dynamic var senderID = ""
    
    @objc dynamic var text: String = ""
    @objc dynamic var mediaPath: String?
    
    @objc dynamic var timestamp = Date()
    
    @objc dynamic var status = ChateeMessageStatus.outgoing.rawValue
    var statusType: ChateeMessageStatus {
        get {
            return ChateeMessageStatus(rawValue: status) ?? .outgoing
        }
        set {
            status = newValue.rawValue
        }
    }
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
}
