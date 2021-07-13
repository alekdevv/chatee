//
//  MessageStorage.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift
import Realm

protocol MessageStorage {
    func loadRecent(completion: @escaping ([ChateeRecentConversation], DatabaseError?) -> Void)
    
    func loadRoom(withID roomID: String, completion: @escaping (ChateeConversation?, DatabaseError?) -> Void)
    func getRoomID(otherUserJID: String, completion: @escaping (String?, DatabaseError?) -> Void)
    func getGroupRoomID(serverRoomID: String, completion: @escaping (String?, DatabaseError?) -> Void)
    func appendGroupRoomUsers(roomID: String, userIDs: [String], completion: @escaping (Bool, DatabaseError?) -> Void)
    func removeRoom(withID roomID: String, completion: @escaping (Bool, DatabaseError?) -> Void)
    
    func saveMessage(withID id: String, text: String, mediaPath: String?, roomID: String, senderID: String, status: ChateeMessageStatus, date: Date, completion: @escaping (ChateeMessage?, DatabaseError?) -> Void)
//    func markConversationMessagesAs(_ messageStatus: ChateeMessageStatus, withUserJid: String, completion: @escaping ([String], DatabaseError?) -> Void)
    func markMessageAs(_ messageStatus: ChateeMessageStatus, messageID: String, date: Date, completion: @escaping (Bool, DatabaseError?) -> Void)
    func changeArchivedMessageTimestamp(messageId: String, newTimestamp: Date, completion: @escaping (Bool, DatabaseError?) -> Void)
    func getLastMessageTimestamp(withRoomId roomId: String, completion: @escaping (Date?, DatabaseError?) -> Void)
    
    func loadOutgoingMessages(completion: @escaping ([OutgoingMessage], DatabaseError?) -> Void)
    
    func checkIfMessageExists(messageId: String, completion: @escaping (Bool, DatabaseError?) -> Void)
}

private let messageWorkQueue = DispatchQueue(label: "messageWorkQueue")

final class MessageStorageManager: MessageStorage {
        
    private lazy var realmConfig: Realm.Configuration = {
        let documentDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let url = documentDirectory.appendingPathComponent("\(self.userBareJid)-chat-db.realm")
        let realmSchemaVersion = Constant.realmSchemaVersion

        let config = Realm.Configuration(
            fileURL: url,
            schemaVersion: realmSchemaVersion,
            migrationBlock: { migration, oldSchemaVersion in
                if (oldSchemaVersion < realmSchemaVersion) { /* Realm handles this automatically. */ }
        })
        
        return config
    }()
    
    private var userBareJid: String {
        return Configuration.shared.userBareJid ?? "no-user-jid" // No user jid scenario shouldn't happen
    }

    init() {
        
    }
    
    func loadRecent(completion: @escaping ([ChateeRecentConversation], DatabaseError?) -> Void) {
        let contactStorage = ContactStorageManager()

        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)
            
            let rooms = realm.objects(RoomDBModel.self)
            
            guard rooms.count > 0 else {
                completion([], nil)
                
                return
            }
            
            var recentConversations = [ChateeRecentConversation]()
            
            rooms.forEach { room in
                guard let lastMessage = room.messages.sorted(byKeyPath: "timestamp", ascending: false).first else { return }
                
                let jid = room.jid
                let name = contactStorage.getName(contactJid: jid)
                let message = ChateeMessage.convert(dbMessage: lastMessage)
                let avatar = contactStorage.getAvatar(contactJid: jid)

                recentConversations.append(ChateeRecentConversation(contact: ChateeContact(jid: jid, name: name, avatar: avatar, subscription: .both), lastMessage: message))
            }
            
            let sortedRecentConversations = recentConversations.sorted { $0.lastMessage.timestamp > $1.lastMessage.timestamp }
            
            completion(sortedRecentConversations, nil)
        }
    }
    
    func loadRoom(withID roomID: String, completion: @escaping (ChateeConversation?, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)
            
            guard let room = realm.objects(RoomDBModel.self).filter("id = '\(roomID)'").first else {
                completion(nil, DatabaseError.noRoomWithId)
                
                return
            }
            
            let roomName = room.displayName
            let messagesList = Array(room.messages.sorted(byKeyPath: "timestamp", ascending: true).suffix(70))
            let messages = ChateeMessage.convert(dbMessages: messagesList)
            
            let conversationModel = ChateeConversation(roomID: roomID, name: roomName, messages: messages)
            
            completion(conversationModel, nil)
        }
    }
    
    func loadOutgoingMessages(completion: @escaping ([OutgoingMessage], DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)
            
            let outgoingDBMessages = realm.objects(MessageDBModel.self).filter("status = 'outgoing'")
            
            var outgoingMessages = [OutgoingMessage]()
            
            outgoingDBMessages.forEach {
                guard let roomId = $0.room?.jid else { return }
                
                let outgoingMessage = OutgoingMessage(remoteMessageId: $0.id, messageText: $0.text, toJid: roomId)
                
                outgoingMessages.append(outgoingMessage)
            }
            
            completion(outgoingMessages, nil)
        }
    }
    
    // TODO: Delete?
    func getRoomID(otherUserJID: String, completion: @escaping (String?, DatabaseError?) -> Void) {
        messageWorkQueue.async {[unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)

            if let room = realm.object(ofType: RoomDBModel.self, forPrimaryKey: otherUserJID) {
                completion(room.jid, DatabaseError.noRoomWithId)
            } else {
                let room = RoomDBModel()
                room.jid = otherUserJID
                room.memberIDs.append(objectsIn: [self.userBareJid, otherUserJID])
                
                do {
                    try realm.write {
                        realm.add(room)

                        completion(room.jid, nil)
                    }
                } catch {
                    completion(nil, DatabaseError.writeFailed)
                }
            }
        }
    }
    
    func getGroupRoomID(serverRoomID: String, completion: @escaping (String?, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)

            if let room = realm.object(ofType: RoomDBModel.self, forPrimaryKey: serverRoomID) {
                completion(room.jid, nil)
            }
        }
    }
    
    func appendGroupRoomUsers(roomID: String, userIDs: [String], completion: @escaping (Bool, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)

            guard let room = realm.object(ofType: RoomDBModel.self, forPrimaryKey: roomID) else {
                completion(false, DatabaseError.noRoomWithId)
                
                return
            }
                        
            do {
                try realm.write {
                    room.memberIDs.append(objectsIn: userIDs)

                    completion(true, nil)
                }
            } catch {
                completion(false, DatabaseError.writeFailed)
            }
        }
    }
    
    func removeRoom(withID roomID: String, completion: @escaping (Bool, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)

            guard let room = realm.object(ofType: RoomDBModel.self, forPrimaryKey: roomID) else {
                completion(false, DatabaseError.noRoomWithId)
                
                return
            }
            
            do {
                try realm.write {
                    realm.delete(room)

                    completion(true, nil)
                }
            } catch {
                completion(false, DatabaseError.writeFailed)
            }
        }
    }

    func saveMessage(withID id: String, text: String, mediaPath: String?, roomID: String, senderID: String, status: ChateeMessageStatus, date: Date, completion: @escaping (ChateeMessage?, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)

            guard realm.object(ofType: MessageDBModel.self, forPrimaryKey: id) == nil else {
                return
            }
            
            let message = MessageDBModel()
            message.id = id
            message.text = text
            message.mediaPath = mediaPath
            message.senderID = senderID
            message.timestamp = date
            
            message.statusType = senderID != roomID ? status : .receivedUnread
            
            if let room = realm.object(ofType: RoomDBModel.self, forPrimaryKey: roomID) {
                do {
                    try realm.write {
                        message.room = room
                        realm.add(message, update: .modified)
                        room.messages.append(message)
                        
                        completion(ChateeMessage.convert(dbMessage: message), nil)
                    }
                } catch {
                    completion(nil, DatabaseError.writeFailed)
                }
            } else {
                let room = RoomDBModel()
                room.jid = roomID
                
                do {
                    try realm.write {
                        realm.add(room)

                        self.saveMessage(withID: id, text: text, mediaPath: mediaPath, roomID: roomID, senderID: senderID, status: status, date: date, completion: completion)
                    }
                } catch {
                    completion(nil, DatabaseError.writeFailed)
                }
            }
            
        }
    }
    
    func getMessage(withId messageId: String, completion: @escaping (ChateeMessage?, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)

            guard let dbMessage = realm.object(ofType: MessageDBModel.self, forPrimaryKey: messageId) else {
                completion(nil, DatabaseError.noMessageWithId)
                return
            }
            
            let message = ChateeMessage.convert(dbMessage: dbMessage)
            
            completion(message, nil)
        }
    }
    
    func getLastMessageTimestamp(withRoomId roomId: String, completion: @escaping (Date?, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)

            guard let dbRoom = realm.object(ofType: RoomDBModel.self, forPrimaryKey: roomId) else {
                completion(nil, DatabaseError.noMessageWithId)
                return
            }
            
            guard let messageTimestamp = dbRoom.messages.sorted(byKeyPath: "timestamp", ascending: false).first?.timestamp else {
                var dateComponents = DateComponents()
                dateComponents.year = 2020
                dateComponents.month = 9
                dateComponents.day = 1
                dateComponents.hour = 8
                dateComponents.minute = 00

                guard let calendarDate = Calendar.current.date(from: dateComponents) else { return }
                
                completion(calendarDate, nil)
                
                return
            }
                        
            completion(messageTimestamp, nil)
        }
    }
    
    func markMessageAs(_ messageStatus: ChateeMessageStatus, messageID: String, date: Date, completion: @escaping (Bool, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)
            
            guard let message = realm.object(ofType: MessageDBModel.self, forPrimaryKey: messageID) else {
                completion(false, DatabaseError.noMessageWithId)
                
                return
            }
            
            do {
                try realm.write {
                    message.statusType = messageStatus
                    
                    completion(true, nil)
                }
            } catch {
                completion(false, DatabaseError.writeFailed)
            }
        }
    }
    
    func changeArchivedMessageTimestamp(messageId: String, newTimestamp: Date, completion: @escaping (Bool, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)
            
            guard let message = realm.object(ofType: MessageDBModel.self, forPrimaryKey: messageId) else {
                completion(false, DatabaseError.noMessageWithId)
                
                return
            }
            
            do {
                try realm.write {
                    message.timestamp = newTimestamp
                    
                    completion(true, nil)
                }
            } catch {
                completion(false, DatabaseError.writeFailed)
            }
        }
    }
    
    func checkIfMessageExists(messageId: String, completion: @escaping (Bool, DatabaseError?) -> Void) {
        messageWorkQueue.async { [unowned self] in
            let realm = try! Realm(configuration: self.realmConfig)
            
            if realm.object(ofType: MessageDBModel.self, forPrimaryKey: messageId) != nil {
                completion(true, nil)
            } else {
                completion(false, nil)
            }
        }
    }
}
