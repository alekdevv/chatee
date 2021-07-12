//
//  SignalHelper.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/12/21.
//
//  * Struct implementation copied from ChatSecure project.
//

import Foundation
import CryptoKit
import OTRKit

// From OMEMO specification:
// 'Divide the HKDF output into a 32-byte encryption key, a 32-byte authentication key and a 16 byte IV.' -- 16 byte IV --
// Crashes on iOS versions prior to 13.0.
// 12 vs 16 bytes? Can lead to incompatibility between systems ( android, ios...)

struct SignalHelper {
    /**
     Encrypt data with IV and key using aes-128-gcm

     - parameter data: The data to be encrypted.
     - parameter key: The symmetric key
     - parameter iv: The initialization vector

     returns: The encrypted data
     */
    static func encryptData(_ data: Data, key: Data, iv: Data) throws -> OTRCryptoData {
        if #available(iOS 13.0, *) {
            let nonce = try AES.GCM.Nonce(data: iv)
            let symmetricKey = SymmetricKey(data: key)
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)

            return OTRCryptoData(data: sealedBox.ciphertext, authTag: sealedBox.tag)
        } else {
            return try OTRCryptoUtility.encryptAESGCMData(data, key: key, iv: iv)
        }
    }

    /**
     Decrypt data with IV and key using aes-128-gcm

     - parameter data: The data to be decrypted.
     - parameter key: The symmetric key
     - parameter iv: The initialization vector

     returns: The decrypted data
     */
    static func decryptData(_ data: Data, key: Data, iv: Data, authTag: Data) throws -> Data? {
        // CryptoKit only accepts 12-byte IVs
        if #available(iOS 13.0, *), iv.count == 12 {
            let nonce = try AES.GCM.Nonce(data: iv)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: data, tag: authTag)
            let symmetricKey = SymmetricKey(data: key)
            
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } else {
            let cryptoData = OTRCryptoData(data: data, authTag: authTag)
            
            return try OTRCryptoUtility.decryptAESGCMData(cryptoData, key: key, iv: iv)
        }
    }

    /** Generates random key of length 16 bytes*/
    static func generateSymmetricKey() -> Data? {
        return KeyGenerator.randomData(withLength: 16)
    }

    /** Generates random iv of length 12 bytes, */ // ??
    static func generateIV(withLength length: Int = 16) -> Data? {
        // I need to check if
        if #available(iOS 13.0, *) {
//            return Data(AES.GCM.Nonce())
            return KeyGenerator.randomData(withLength: length)
        } else {
            // In ChatSecure was 12
            return KeyGenerator.randomData(withLength: length)
        }
    }
    
}
