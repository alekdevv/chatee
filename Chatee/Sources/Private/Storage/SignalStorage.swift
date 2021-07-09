//
//  SignalStorage.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift
import Realm
import SignalProtocolObjC
import XMPPFramework

private let signalWorkQueue = DispatchQueue(label: "signalWorkQueue")

/// All Signal related database methods are on the main thread! Signal third party library is using them without callbacks!
class SignalStorageManager: NSObject, SignalStore {
    
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

    weak var signalContext: SignalContext?
    
    private var userBareJid: String {
        return Configuration.shared.userBareJid ?? "no-user-jid" // No user jid scenario shouldn't happen
    }

    private var keyHelper: SignalKeyHelper? {
        guard let context = self.signalContext else { return nil }
        
        return SignalKeyHelper(context: context)
    }
    
    /**
     This fetches the associated account's bundle from database. If any piece of the bundle is missing it returns nil.
     - returns: A complete outgoing bundle.
     */
    func fetchThisUserExistingBundle() throws -> OMEMOBundle {
        let realm = try! Realm(configuration: realmConfig)
        
        guard let signedPreKeyDB = realm.objects(SignedPreKeyDBModel.self).first, let identityDB = realm.objects(SignalIdentityDBModel.self).first else {
            throw OMEMOBundleError.notFound
        }
        
        let preKeysDB = fetchAllPreKeys()
        
        let bundle = try OMEMOBundle(identity: identityDB, signedPreKey: signedPreKeyDB, preKeys: preKeysDB)
                
        return bundle
    }

    /**
     Fetch all pre-keys for this class's account. This can include deleted pre-keys which are PreKeyDBModel witout any keyData.
     
     - returns: An array of OTRSignalPreKey(s). If ther eare no pre-keys then the array will be empty.
     */
    func fetchAllPreKeys() -> [PreKeyDBModel] {
        let realm = try! Realm(configuration: realmConfig)
        
        let preKeysDB = realm.objects(PreKeyDBModel.self)
        
        return Array(preKeysDB)
    }
    
    /**
     Returns the current max pre-key id for this account. This includes both deleted and existing pre-keys. This is fairly quick as it uses a secondary index and
     aggregate function MAX(OTRYapDatabaseSignalPreKeyIdSecondaryIndexColumnName) WHERE OTRYapDatabaseSignalPreKeyAccountKeySecondaryIndexColumnName =?, self.accountKey
     - returns: The current max in the yap database. If there are no pre-keys then returns none.
    */
    func currentMaxPreKeyId() ->  UInt32? {
        let realm = try! Realm(configuration: realmConfig)

        guard let maxKeyId = realm.objects(PreKeyDBModel.self).last?.keyId else { return nil }
        
        return UInt32(maxKeyId)
    }

    func storeSignalPreKeys(_ preKeys: [SignalPreKey]) -> Bool {
        if preKeys.count == 0 {
            return true
        }
        
        var success = false
        
        for preKey in preKeys {
            if let data = preKey.serializedData() {
                success = self.storePreKey(data, preKeyId: preKey.preKeyId)
            } else {
                success = false
            }
            
            if !success {
                break
            }
        }

        return true
    }
    
    private func generateNewIdentity() -> SignalIdentityDBModel? {
        let realm = try! Realm(configuration: realmConfig)

        guard let keyHelper = self.keyHelper else { return nil }
        
        if let identity = realm.objects(SignalIdentityDBModel.self).first {
            return identity
        }
        
        let keyPair = keyHelper.generateIdentityKeyPair()!
        let registrationId = keyHelper.generateRegistrationId()
        
        var identityDB: SignalIdentityDBModel?
        
        try! realm.write {
            identityDB = SignalIdentityDBModel()
            identityDB!.privateKey = keyPair.privateKey
            identityDB!.publicKey = keyPair.publicKey
            identityDB!.registrationId = Int(registrationId)

            realm.add(identityDB!)
        }
        
        return identityDB
    }
}

// MARK: - SignalSessionStore

extension SignalStorageManager {
    
    func sessionRecord(for address: SignalAddress) -> Data? {
        let realm = try! Realm(configuration: realmConfig)
        let deviceId = address.deviceId
        
        let session = realm.object(ofType: SessionDBModel.self, forPrimaryKey: deviceId)
        
        return session?.sessionData
    }
    
    func storeSessionRecord(_ recordData: Data, for address: SignalAddress) -> Bool {
        let realm = try! Realm(configuration: realmConfig)

        do {
            try realm.write {
                let sessionDB = SessionDBModel()
                sessionDB.name = address.name
                sessionDB.deviceId = Int(address.deviceId)
                sessionDB.sessionData = recordData
                
                realm.add(sessionDB, update: .modified)
            }
        } catch {
            return false
        }
        
        return true
    }
    
    func sessionRecordExists(for address: SignalAddress) -> Bool {
        return sessionRecord(for: address) != nil
    }
    
    func deleteSessionRecord(for address: SignalAddress) -> Bool {
        let realm = try! Realm(configuration: realmConfig)
        let deviceId = address.deviceId

        guard let sessionDB = realm.object(ofType: SessionDBModel.self, forPrimaryKey: deviceId) else {
            return false
        }
        
        do {
            try realm.write {
                realm.delete(sessionDB)
            }
        } catch {
            return false
        }
        
        return true
    }
    
    func allDeviceIds(forAddressName addressName: String) -> [NSNumber] {
        let realm = try! Realm(configuration: realmConfig)

        let deviceIdsDB = realm.objects(OmemoDeviceDBModel.self).filter("userJid == '\(addressName)'").map { return $0.id }
        let deviceIdsArray = Array(deviceIdsDB)
        let deviceIds = deviceIdsArray.map { return NSNumber(integerLiteral: Int($0)) }
        
        return deviceIds
    }
    
    func deleteAllSessions(forAddressName addressName: String) -> Int32 {
        return 0
    }
}
    
// MARK: - SignalPreKeyStore

extension SignalStorageManager {

    func loadPreKey(withId preKeyId: UInt32) -> Data? {
        let realm = try! Realm(configuration: realmConfig)
        
        let preKey = realm.object(ofType: PreKeyDBModel.self, forPrimaryKey: preKeyId)
        
        return preKey?.keyData
    }
    
    func storePreKey(_ preKey: Data, preKeyId: UInt32) -> Bool {
        let realm = try! Realm(configuration: realmConfig)

        do {
            try realm.write {
                let preKeyDB = PreKeyDBModel()
                preKeyDB.keyId = Int(preKeyId)
                preKeyDB.keyData = preKey
                
                realm.add(preKeyDB, update: .all)
            }
        } catch {
            return false
        }
        
        return true
    }
    
    func containsPreKey(withId preKeyId: UInt32) -> Bool {
        return loadPreKey(withId: preKeyId) != nil
    }
    
    func deletePreKey(withId preKeyId: UInt32) -> Bool {
        let realm = try! Realm(configuration: realmConfig)

        do {
            try realm.write {
                guard let preKey = realm.object(ofType: PreKeyDBModel.self, forPrimaryKey: preKeyId) else {
                    throw OMEMOBundleError.notFound
                }
                
                realm.delete(preKey)
            }
        } catch {
            return false
        }
        
        return true
    }
}

// MARK: - SignalSignedPreKeyStore

extension SignalStorageManager {

    func loadSignedPreKey(withId signedPreKeyId: UInt32) -> Data? {
        let realm = try! Realm(configuration: realmConfig)

        let signedPreKey = realm.objects(SignedPreKeyDBModel.self).first
        
        return signedPreKey?.keyData
    }
    
    func storeSignedPreKey(_ signedPreKey: Data, signedPreKeyId: UInt32) -> Bool {
        let realm = try! Realm(configuration: realmConfig)

        do {
            try realm.write {
                let signedPreKeyDB = SignedPreKeyDBModel()
                signedPreKeyDB.keyId = Int(signedPreKeyId)
                signedPreKeyDB.keyData = signedPreKey
                
                realm.add(signedPreKeyDB, update: .all)
            }
        } catch {
            return false
        }
        
        return true
    }
    
    func containsSignedPreKey(withId signedPreKeyId: UInt32) -> Bool {
        return loadSignedPreKey(withId: signedPreKeyId) != nil
    }
    
    func removeSignedPreKey(withId signedPreKeyId: UInt32) -> Bool {
        let realm = try! Realm(configuration: realmConfig)

        do {
            try realm.write {
                guard let signedPreKey = realm.object(ofType: SignedPreKeyDBModel.self, forPrimaryKey: signedPreKeyId) else {
                    throw OMEMOBundleError.notFound
                }
                
                realm.delete(signedPreKey)
            }
        } catch {
            return false
        }
        
        return true
    }
}

// MARK: - SignalIdentityKeyStore

extension SignalStorageManager {
    
    func getIdentityKeyPair() -> SignalIdentityKeyPair {
        let realm = try! Realm(configuration: realmConfig)

        guard let identityDB = realm.objects(SignalIdentityDBModel.self).first else {
            let newIdentity = self.generateNewIdentity()!
            
            let newIdentityKeyPair = try! SignalIdentityKeyPair(publicKey: newIdentity.publicKey, privateKey: newIdentity.privateKey)
            
            return newIdentityKeyPair
        }
        
        let identityKeyPair = try! SignalIdentityKeyPair(publicKey: identityDB.publicKey, privateKey: identityDB.privateKey)
        
        return identityKeyPair
    }
    
    func getLocalRegistrationId() -> UInt32 {
        let realm = try! Realm(configuration: realmConfig)

        guard let identityDB = realm.objects(SignalIdentityDBModel.self).first else {
            if let newIdentity = generateNewIdentity() {
                return UInt32(newIdentity.registrationId)
            }

            return 0
        }

        let registrationId = UInt32(identityDB.registrationId)
        
        return registrationId
    }
    
    // TODO: Save Identity
    func saveIdentity(_ address: SignalAddress, identityKey: Data?) -> Bool {
        return true
    }
    
    func isTrustedIdentity(_ address: SignalAddress, identityKey: Data) -> Bool {
        return true
    }
}

// MARK: - SignalSenderKeyStore

extension SignalStorageManager {

    func storeSenderKey(_ senderKey: Data, address: SignalAddress, groupId: String) -> Bool {
        return true
    }
    
    func loadSenderKey(for address: SignalAddress, groupId: String) -> Data? {
        return nil
    }
}
