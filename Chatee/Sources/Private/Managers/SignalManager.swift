//
//  SignalManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/12/21.
//

import Foundation
import SignalProtocolObjC
import XMPPFramework

enum SignalEncryptionError: Error {
    case unableToCreateSignalContext
}

/// Performs Signal operations: creating bundle, decryption, encryption. One per account.
class SignalManager {
    
    let signalStorageManager: SignalStorageManager
    let signalStorage: SignalStorage
    private let signalContext: SignalContext
    
    weak var omemoModule: OMEMOModule?
    
    // In OMEMO world the registration ID is used as the device ID
    var registrationId: UInt32 {
        return self.signalStorageManager.getLocalRegistrationId()
    }
    
    private var identityKeyPair: SignalIdentityKeyPair {
        return self.signalStorageManager.getIdentityKeyPair()
    }
    
    private var keyHelper: SignalKeyHelper? {
        return SignalKeyHelper(context: self.signalContext)
    }

    init() throws {
        self.signalStorageManager = SignalStorageManager()
        self.signalStorage = SignalStorage(signalStore: self.signalStorageManager)
        
        guard let context = SignalContext(storage: signalStorage) else {
            throw SignalEncryptionError.unableToCreateSignalContext
        }
        
        self.signalContext = context
        self.signalStorageManager.signalContext = signalContext
    }
    
}

// MARK: - Generate Identity/PreKeys/SignedPreKey

extension SignalManager {
    
    func generateNewRegistrationId() -> UInt32 {
        guard let registrationId = keyHelper?.generateRegistrationId() else { return 0 }

        return registrationId
    }
    
    func generateNewIdentityKeyPair() -> SignalIdentityKeyPair? {
        guard let keyPair = keyHelper?.generateIdentityKeyPair() else { return nil }
        
        let identityPair = try? SignalIdentityKeyPair(publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)
        
        return identityPair
    }

    func generatePreKeys(_ start: UInt, count: UInt) -> [SignalPreKey]? {
        guard let preKeys = self.keyHelper?.generatePreKeys(withStartingPreKeyId: start, count: count) else { return nil }
        
        if self.signalStorageManager.storeSignalPreKeys(preKeys) {
            return preKeys
        }
        
        return nil
    }

    func generateRandomSignedPreKey() -> SignalSignedPreKey? {
        guard let preKeyId = self.keyHelper?.generateRegistrationId() else { return nil }
        guard let signedPreKey = self.keyHelper?.generateSignedPreKey(withIdentity: self.identityKeyPair, signedPreKeyId:preKeyId), let data = signedPreKey.serializedData() else { return nil }
        
        if self.signalStorageManager.storeSignedPreKey(data, signedPreKeyId: signedPreKey.preKeyId) {
            return signedPreKey
        }
        
        return nil
    }
    
}

// MARK: - Incoming/Outgoing Bundle

extension SignalManager {
    
    /// This creates all the information necessary to publish a 'bundle' to your XMPP server via PEP. It generates prekeys 0 to 99.
    public func generateOutgoingBundle(_ preKeyCount: Int) throws -> OMEMOBundle {
        let identityKeyPair = self.signalStorageManager.getIdentityKeyPair()
        let deviceId = self.registrationId
        
        // Fetch existing signed pre-key to prevent regeneration
        // The existing storage code only allows for storage of
        // a single signedPreKey per account, so regeneration
        // will break things.
        let signedPreKeyStoredData = signalStorageManager.loadSignedPreKey(withId: 0)
        let signalSignedPreKey = signedPreKeyStoredData != nil ? try SignalSignedPreKey(serializedData: signedPreKeyStoredData!) : generateRandomSignedPreKey()
        
        guard let signedPreKey = signalSignedPreKey, let signedPreKeyData = signedPreKey.serializedData() else {
            throw OMEMOBundleError.keyGeneration
        }
        
        guard let preKeys = self.generatePreKeys(1, count: UInt(preKeyCount)) else {
            throw OMEMOBundleError.keyGeneration
        }
        
        let bundle = try! OMEMOBundle(deviceId: deviceId, identity: identityKeyPair, signedPreKey: signedPreKey, preKeys: preKeys)

        _ = self.signalStorageManager.storeSignedPreKey(signedPreKeyData, signedPreKeyId: signedPreKey.preKeyId)
        
        return bundle
    }
    
    /// This processes fetched OMEMO bundles. After you consume a bundle you can then create preKeyMessages to send to the contact.
    
    public func consumeIncomingBundle(_ name: String, bundle: OMEMOBundle) throws {
        let deviceId = Int32(bundle.deviceId)
        let incomingAddress = SignalAddress(name: name.lowercased(), deviceId: deviceId)
        let sessionBuilder = SignalSessionBuilder(address: incomingAddress, context: self.signalContext)
        let preKeyBundle = try bundle.signalBundle()

        return try sessionBuilder.processPreKeyBundle(preKeyBundle)
    }
    
}

// MARK: - Encrypt/Decrypt

extension SignalManager {
    
    public func encryptToAddress(_ data: Data, name: String, deviceId: Int32) throws -> SignalCiphertext {
        let address = SignalAddress(name: name.lowercased(), deviceId: deviceId)
        let sessionCipher = SignalSessionCipher(address: address, context: self.signalContext)
        
        return try sessionCipher.encryptData(data)
    }
    
    public func decryptFromAddress(_ data: Data, name: String, deviceId: Int32) throws -> Data {
        let address = SignalAddress(name: name.lowercased(), deviceId: deviceId)
        let sessionCipher = SignalSessionCipher(address: address, context: self.signalContext)
        let cipherText = SignalCiphertext(data: data, type: .unknown)
        
        return try sessionCipher.decryptCiphertext(cipherText)
    }
    
}

// MARK: - Session methods

extension SignalManager {
    
    public func sessionRecordExistsForUsername(_ username: String, deviceId: Int32) -> Bool {
        let address = SignalAddress(name: username.lowercased(), deviceId: deviceId)
        
        return self.signalStorageManager.sessionRecordExists(for: address)
    }

    public func removeSessionRecordForUsername(_ username: String, deviceId: Int32) -> Bool {
        let address = SignalAddress(name: username.lowercased(), deviceId: deviceId)
        
        return self.signalStorageManager.deleteSessionRecord(for: address)
    }
    
}
