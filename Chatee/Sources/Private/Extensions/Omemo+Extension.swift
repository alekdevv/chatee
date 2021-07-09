//
//  Omemo+Extension.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import XMPPFramework
import SignalProtocolObjC

extension OMEMOPreKey {
    static func preKeysFromSignal(_ preKeys: [SignalPreKey]) -> [OMEMOPreKey] {
        var omemoPreKeys: [OMEMOPreKey] = []
        preKeys.forEach { (signalPreKey) in
            guard let pk = signalPreKey.keyPair?.publicKey else { return }
            let omemoPreKey = OMEMOPreKey(preKeyId: signalPreKey.preKeyId, publicKey: pk)
            omemoPreKeys.append(omemoPreKey)
        }
        return omemoPreKeys
    }
}

extension OMEMOSignedPreKey {
    convenience init(signedPreKey: SignedPreKeyDBModel) throws {
        let signalSignedPreKey = try SignalSignedPreKey(serializedData: signedPreKey.keyData)
        
        guard let pk = signalSignedPreKey.keyPair?.publicKey else {
            throw OMEMOBundleError.invalid
        }
        
        self.init(preKeyId: UInt32(signedPreKey.keyId), publicKey: pk, signature: signalSignedPreKey.signature)
    }
    convenience init(signedPreKey: SignalSignedPreKey) throws {
        guard let publicKey = signedPreKey.keyPair?.publicKey else {
            throw OMEMOBundleError.invalid
        }
        
        self.init(preKeyId: signedPreKey.preKeyId, publicKey: publicKey, signature: signedPreKey.signature)
    }
}

extension OMEMOBundle {
    
    /// Returns copy of bundle with new preKeys
    func copyBundle(newPreKeys: [OMEMOPreKey]) -> OMEMOBundle {
        let bundle = OMEMOBundle(deviceId: deviceId, identityKey: identityKey, signedPreKey: signedPreKey, preKeys: newPreKeys)
        
        return bundle
    }
    
    /// Returns Signal bundle from a random PreKey
    func signalBundle() throws -> SignalPreKeyBundle {
        let index = Int(arc4random_uniform(UInt32(preKeys.count)))
        let preKey = preKeys[index]
        let preKeyBundle = try SignalPreKeyBundle(registrationId: 0, deviceId: deviceId, preKeyId: preKey.preKeyId, preKeyPublic: preKey.publicKey, signedPreKeyId: signedPreKey.preKeyId, signedPreKeyPublic: signedPreKey.publicKey, signature: signedPreKey.signature, identityKey: identityKey)
        
        return preKeyBundle
    }
    
    convenience init(deviceId: UInt32, identity: SignalIdentityKeyPair, signedPreKey: SignalSignedPreKey, preKeys: [SignalPreKey]) throws {
        let omemoSignedPreKey = try OMEMOSignedPreKey(signedPreKey: signedPreKey)
        let omemoPreKeys = OMEMOPreKey.preKeysFromSignal(preKeys)
        
        // Double check that this bundle is valid
        if let preKey = preKeys.first,
            let preKeyPublic = preKey.keyPair?.publicKey {
            let _ = try SignalPreKeyBundle(registrationId: 0, deviceId: deviceId, preKeyId: preKey.preKeyId, preKeyPublic: preKeyPublic, signedPreKeyId: omemoSignedPreKey.preKeyId, signedPreKeyPublic: omemoSignedPreKey.publicKey, signature: omemoSignedPreKey.signature, identityKey: identity.publicKey)
        } else {
            throw OMEMOBundleError.invalid
        }
        
        self.init(deviceId: deviceId, identityKey: identity.publicKey, signedPreKey: omemoSignedPreKey, preKeys: omemoPreKeys)
    }
    
    convenience init(identity: SignalIdentityDBModel, signedPreKey: SignedPreKeyDBModel, preKeys: [PreKeyDBModel]) throws {
        let omemoSignedPreKey = try OMEMOSignedPreKey(signedPreKey: signedPreKey)
        
        var omemoPreKeys: [OMEMOPreKey] = []
        preKeys.forEach { (preKey) in
            let keyData = preKey.keyData
            
            guard keyData.count > 0 else { return }
            do {
                let signalPreKey = try SignalPreKey(serializedData: keyData)
                guard let pk = signalPreKey.keyPair?.publicKey else { return }
                
                let omemoPreKey = OMEMOPreKey(preKeyId: UInt32(preKey.keyId), publicKey: pk)
                omemoPreKeys.append(omemoPreKey)
            } catch {
//                DDLogError("Found invalid prekey: \(error)")
            }
        }
        
        // Double check that this bundle is valid
        if let preKey = preKeys.first, preKey.keyData.count > 0,
            let signalPreKey = try? SignalPreKey(serializedData: preKey.keyData),
            let preKeyPublic = signalPreKey.keyPair?.publicKey {
            let _ = try SignalPreKeyBundle(registrationId: 0, deviceId: UInt32(identity.registrationId), preKeyId: UInt32(preKey.keyId), preKeyPublic: preKeyPublic,
                                           signedPreKeyId: omemoSignedPreKey.preKeyId, signedPreKeyPublic: omemoSignedPreKey.publicKey, signature: omemoSignedPreKey.signature,
                                           identityKey: identity.publicKey)
        } else {
            throw OMEMOBundleError.invalid
        }
        
        self.init(deviceId: UInt32(identity.registrationId), identityKey: identity.publicKey, signedPreKey: omemoSignedPreKey, preKeys: omemoPreKeys)
    }
}
