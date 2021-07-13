//
//  OmemoStorage.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import RealmSwift
import Realm

private let omemoWorkQueue = DispatchQueue(label: "omemoWorkQueue")

final class OmemoStorageManager {
    
    private lazy var realmConfig: Realm.Configuration = {
        let documentDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let url = documentDirectory.appendingPathComponent("\(userBareJid)-chat-db.realm")
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
    
    /**
     Convenience method that uses the class database connection.
     Retrievs all the devices for a given jid. Could be either for a contact or an account.
     - parameter jid: The JID for account or buddy
     - returns: An Array of OMEMODevices. If there are no devices the array will be empty.
     */
    func getDevicesForJID(_ jid: String) -> [Int] {
        guard let realm = try? Realm(configuration: self.realmConfig) else {
            assert(false)
            return []
        }

        let devices = realm.objects(OmemoDeviceDBModel.self).filter("userJid = '\(jid)'").map { $0.id }
        
        return Array(devices)
    }
    
    func checkIfDeviceIsStored(deviceId: Int) -> Bool {
        guard let realm = try? Realm(configuration: self.realmConfig) else {
            assert(false)
            return false
        }

        return realm.object(ofType: OmemoDeviceDBModel.self, forPrimaryKey: deviceId) != nil
    }
    
    func checkIfDevicesAreStored(forJid: String) -> Bool {
        guard let realm = try? Realm(configuration: self.realmConfig) else {
            assert(false)
            return false
        }

        return realm.objects(OmemoDeviceDBModel.self).filter("userJid = '\(forJid)'").first != nil
    }
    
    func addDevice(for userJid: String, deviceId: Int) {
        guard let realm = try? Realm(configuration: self.realmConfig) else {
            assert(false)
            return
        }

        guard !checkIfDeviceIsStored(deviceId: deviceId) else { return }
        
        try? realm.write {
            let device = OmemoDeviceDBModel()
            device.id = deviceId
            device.userJid = userJid
            device.trustLevelType = .trustedTofu
            
            realm.add(device, update: .modified)
        }
    }
    
    /**
     Uses the class account key and collection to get all devices.
     - returns: An Array of OMEMODevices. If there are no devices the array will be empty.
     */
    func getDevicesForThisAccount() -> [Int] {
        let thisUserDevices = getDevicesForJID(userBareJid)
        
        return thisUserDevices
    }
    
    /**
     Store devices
     - parameter devices: An array of the device numbers. Should be UInt32.
     - parameter jid: The yap key to attach the device to
     */
    private func storeDevices(_ deviceIds: [NSNumber], jid: String) {
        Logger.shared.log("storeDevices called for \(jid), devices: \(deviceIds)", level: .verbose)
        
        guard let realm = try? Realm(configuration: realmConfig) else {
            assert(false)
            return
        }
        
        let previouslyStoredDevices = Array(realm.objects(OmemoDeviceDBModel.self).filter("userJid == '\(jid)'"))
        
        let previouslyStoredDevicesIds = previouslyStoredDevices.map { return NSNumber(value: $0.id) }
        let previouslyStoredDevicesIdSet = Set(previouslyStoredDevicesIds)
        
        let newDeviceSet = Set(deviceIds)
        
        if deviceIds.count == 0 {
            // Remove all devices
            previouslyStoredDevices.forEach {
                self.removeDevice(withId: $0.id)
            }
        } else if previouslyStoredDevicesIdSet != newDeviceSet {
            // New Devices to be saved and list to be reworked
            let devicesToRemove: Set<NSNumber> = previouslyStoredDevicesIdSet.subtracting(newDeviceSet)
            let devicesToAdd:Set<NSNumber> = newDeviceSet.subtracting(previouslyStoredDevicesIdSet)
            
            // Instead of fulling removing devices, mark them as removed for historical purposes
            devicesToRemove.forEach { deviceId in
                guard let device = realm.object(ofType: OmemoDeviceDBModel.self, forPrimaryKey: deviceId) else { return }
                
                try? realm.write {
                    device.trustLevelType = .removed
                    
                    realm.add(device, update: .modified)
                }
            }
            
            devicesToAdd.forEach{ deviceId in
                var trustLevel = OmemoTrustLevel.trustedTofu
                
                if previouslyStoredDevices.count == 0 {
                    // This is the first time we're seeing a device list for this account/buddy so it should be saved as TOFU
                    trustLevel = .trustedTofu
                }
                
                try? realm.write {
                    let newDevice = OmemoDeviceDBModel()
                    newDevice.trustLevelType = trustLevel
                    newDevice.id = Int(truncating: deviceId)
                    newDevice.userJid = jid
                    
                    realm.add(newDevice, update: .modified)
                }
            }
        }
    }
    
    /**
     Store devices for this account. These should come from the OMEMO device-list
     - parameter deviceIds: An array of the device numbers. Should be UInt32.
     */
    func storeThisUserDevices(_ deviceIds: [NSNumber]) {
        self.storeDevices(deviceIds, jid: userBareJid)
    }
    
    func storeContactDevices(_ devices: [NSNumber], contactJid: String, completion: (() -> Void)?) {
        self.storeDevices(devices, jid: contactJid)
        completion?()
    }
    
    private func removeDevice(withId deviceId: Int) {
        guard let realm = try? Realm(configuration: realmConfig) else {
            assert(false)
            return
        }

        try? realm.write {
            guard let device = realm.object(ofType: OmemoDeviceDBModel.self, forPrimaryKey: deviceId) else { return }
            
            realm.delete(device)
        }
    }
    
    func fetchUserForDeviceId(_ deviceId: Int) -> String? {
        guard let realm = try? Realm(configuration: realmConfig) else {
            assert(false)
            return nil
        }

        let deviceDB = realm.object(ofType: OmemoDeviceDBModel.self, forPrimaryKey: deviceId)
        
        return deviceDB?.userJid
    }
}
