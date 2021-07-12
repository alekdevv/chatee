//
//  KeyGenerator.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/12/21.
//

import Foundation

struct KeyGenerator {
    
    static func stringData(withLength length: Int) -> String? {
        let keyData = self.randomData(withLength: length)
        let stringData = keyData?.base64EncodedString()
        
        return stringData
    }

    static func randomData(withLength length: Int) -> Data? {
        var keyData = Data(count: length)
        
        let result = keyData.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!) }
        
        return result == errSecSuccess ? keyData : nil
    }
    
}
