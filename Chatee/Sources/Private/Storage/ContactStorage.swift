//
//  ContactStorage.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift
import Realm

protocol ContactStorage {
    func addContact(_ contact: ChateeContact, completion: @escaping (ChateeContact?, DatabaseError?) -> Void)
    func removeContact(_ contact: ChateeContact, completion: @escaping (ChateeContact?, DatabaseError?) -> Void)

    func loadContacts(subscriptionType: ChateeContactSubscription, completion: @escaping ([ChateeContact], DatabaseError?) -> Void)
    func refreshContacts(contacts: [ChateeContact], completion: @escaping (Bool?, DatabaseError?) -> Void)

    func acceptSubscription(contactJid: String, completion: @escaping (ChateeContact?, DatabaseError?) -> Void)
    func rejectSubscription(contactJid: String, completion: @escaping (Bool, DatabaseError?) -> Void)
    
    func saveAvatar(_ avatar: Data, contactJid: String, completion: @escaping (Data?, DatabaseError?) -> Void)
    func getName(contactJid: String) -> String?
    func getAvatar(contactJid: String) -> Data?
}

private let contactsWorkQueue = DispatchQueue(label: "contactsWorkQueue")

final class ContactStorageManager: ContactStorage {
    
    private lazy var realmConfig: Realm.Configuration = {
        let documentDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let url = documentDirectory.appendingPathComponent("\(self.userBareJid)-chat-db.realm")
        let realmSchemaVersion = Constant.realmSchemaVersion

        let config = Realm.Configuration( fileURL: url, schemaVersion: realmSchemaVersion, migrationBlock: { migration, oldSchemaVersion in
                if (oldSchemaVersion < realmSchemaVersion) { /* Realm handles this automatically. */ }
        })
        
        return config
    }()
    
    private var userBareJid: String {
        return Configuration.shared.userBareJid ?? "no-user-jid" // No user jid scenario shouldn't happen
    }
    
    init() {

    }

    func addContact(_ contact: ChateeContact, completion: @escaping (ChateeContact?, DatabaseError?) -> Void) {
        contactsWorkQueue.async {
            guard let realm = try? Realm(configuration: self.realmConfig) else {
                completion(nil, DatabaseError.databaseAccessFailed)
                return
            }
            
            guard realm.object(ofType: ContactDBModel.self, forPrimaryKey: contact.jid) == nil ||
                realm.object(ofType: ContactDBModel.self, forPrimaryKey: contact.jid)?.subscriptionType != contact.subscription else {
                return
            }

            do {
                try realm.write {
                    let contactDB = ContactDBModel()
                    contactDB.jid = contact.jid
                    contactDB.name = contact.name
                    contactDB.avatar = contact.avatar
                    contactDB.subscriptionType = contact.subscription
                    
                    realm.add(contactDB, update: .modified)
                    
                    completion(contact, nil)
                }
            } catch {
                completion(nil, DatabaseError.writeFailed)
            }
        }
    }
    
    func removeContact(_ contact: ChateeContact, completion: @escaping (ChateeContact?, DatabaseError?) -> Void) {
        contactsWorkQueue.async {
            guard let realm = try? Realm(configuration: self.realmConfig) else {
                completion(nil, DatabaseError.databaseAccessFailed)
                return
            }
            
            do {
                try realm.write {
                    guard let contactDB = realm.object(ofType: ContactDBModel.self, forPrimaryKey: contact.jid) else {
                        completion(nil, DatabaseError.noContactWithJid)
                        
                        return
                    }
                    
                    realm.delete(contactDB)
                    
                    completion(contact, nil)
                }
            } catch {
                completion(nil, DatabaseError.writeFailed)
            }
        }
    }
    
    func loadContacts(subscriptionType: ChateeContactSubscription, completion: @escaping ([ChateeContact], DatabaseError?) -> Void) {
        contactsWorkQueue.async {
            guard let realm = try? Realm(configuration: self.realmConfig) else {
                completion([], DatabaseError.databaseAccessFailed)
                return
            }
            
            var contacts = [ChateeContact]()

            let contactsDB = realm.objects(ContactDBModel.self).filter("subscription = '\(subscriptionType.rawValue)'")
            
            contactsDB.forEach {
                let contact = ChateeContact(jid: $0.jid, name: $0.name, avatar: $0.avatar, subscription: $0.subscriptionType)
                
                contacts.append(contact)
            }
            
            completion(contacts, nil)
        }
        
    }
    
    func refreshContacts(contacts: [ChateeContact], completion: @escaping (Bool?, DatabaseError?) -> Void) {
        // TODO: Implement contacts refresh
    }
    
    func acceptSubscription(contactJid: String, completion: @escaping (ChateeContact?, DatabaseError?) -> Void) {
        contactsWorkQueue.async {
            guard let realm = try? Realm(configuration: self.realmConfig) else {
                completion(nil, DatabaseError.databaseAccessFailed)
                return
            }
            
            guard let contactDB = realm.object(ofType: ContactDBModel.self, forPrimaryKey: contactJid) else {
                completion(nil, DatabaseError.noContactWithJid)
                
                return
            }
            
            do {
                try realm.write {
                    contactDB.subscriptionType = .both
                    
                    realm.add(contactDB, update: .modified)
                    
                    let contact = ChateeContact(jid: contactDB.jid, name: contactDB.name, avatar: contactDB.avatar, subscription: contactDB.subscriptionType)
                    
                    completion(contact, nil)
                }
            } catch {
                completion(nil, DatabaseError.writeFailed)
            }
        }
    }
    
    func rejectSubscription(contactJid: String, completion: @escaping (Bool, DatabaseError?) -> Void) {
        contactsWorkQueue.async {
            guard let realm = try? Realm(configuration: self.realmConfig) else {
                completion(false, DatabaseError.databaseAccessFailed)
                return
            }
            
            guard let contactDB = realm.object(ofType: ContactDBModel.self, forPrimaryKey: contactJid) else {
                completion(false, DatabaseError.noContactWithJid)
                
                return
            }
            
            do {
                try realm.write {
                    realm.delete(contactDB)
                    
                    completion(true, nil)
                }
            } catch {
                completion(false, DatabaseError.writeFailed)
            }
        }
    }

    func saveAvatar(_ avatar: Data, contactJid: String, completion: @escaping (Data?, DatabaseError?) -> Void) {
        contactsWorkQueue.async {
            guard let realm = try? Realm(configuration: self.realmConfig) else {
                completion(nil, DatabaseError.databaseAccessFailed)
                return
            }
            
            if let contact = realm.object(ofType: ContactDBModel.self, forPrimaryKey: contactJid) {
                try? realm.write {
                    contact.avatar = avatar
                    
                    completion(contact.avatar, nil)
                }
            } else {
                try? realm.write {
                    let contact = ContactDBModel()
                    contact.jid = contactJid
                    
                    realm.add(contact)
                    
                    completion(contact.avatar, nil)
                }
            }
        }
    }
    
    func getName(contactJid: String) -> String? {
        guard let realm = try? Realm(configuration: self.realmConfig) else {
            return nil
        }
        
        let contact = realm.object(ofType: ContactDBModel.self, forPrimaryKey: contactJid)
        
        return contact?.name
    }
    
    func getAvatar(contactJid: String) -> Data? {
        guard let realm = try? Realm(configuration: self.realmConfig) else {
            return nil
        }
        
        let contact = realm.object(ofType: ContactDBModel.self, forPrimaryKey: contactJid)
        
        return contact?.avatar
    }
}
