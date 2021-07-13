//
//  SenderKeyDBModel.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift

final class SenderKeyDBModel: Object {
    
    @objc dynamic var name = ""
    @objc dynamic var deviceId = 0
    @objc dynamic var groupId = ""
    @objc dynamic var senderKey = Data()
    
}
