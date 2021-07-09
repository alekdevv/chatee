//
//  Errors.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation

enum XMPPError: Error {
    case streamConnectionError
    case authenticationError
    case notAuthenticated
    case messageNotSent
    case chatStateError
    
    public var localizedDescription: String {
        switch self {
        case .streamConnectionError:
            return "streamConnectionError"
        case .authenticationError:
            return "authenticationError"
        case .notAuthenticated:
            return "notAuthenticated"
        case .messageNotSent:
            return "messageNotSent"
        case .chatStateError:
            return "chatStateError"
        }
    }
}

enum DatabaseError: Error {
    case noRooms
    case noRoomWithId
    case noMessageWithId
    case noContactWithJid
    case writeFailed
    
    case messageStorageNotSet
    case contactStorageNotSet

    var localizedDescription: String {
        switch self {
        case .noRooms:
            return "noRooms"
        case .noRoomWithId:
            return "noRoomWithId"
        case .noMessageWithId:
            return "noMessageWithId"
        case .noContactWithJid:
            return "case noContactWithJid"
        case .writeFailed:
            return "writeFailed"
        case .messageStorageNotSet:
            return "messageStorageNotSet"
        case .contactStorageNotSet:
            return "contactStorageNotSet"
        }
    }
}

enum EncryptionError: Error {
    case failedToEncrypt(messageId: String)
    case failedToDecrypt
    case failedToPublishDeviceIds
    case failedToFetchDeviceIdsFor(jid: String)
    
    case omemoManagerNotSet
    
    var localizedDescription: String {
        switch self {
        case .failedToEncrypt:
            return "failedToEncrypt"
        case .failedToDecrypt:
            return "failedToDecrypt"
        case .failedToPublishDeviceIds:
            return "failedToPublishDeviceIds"
        case .failedToFetchDeviceIdsFor(let jid):
            return "failedToFetchDeviceIdsFor: \(jid)"
        case .omemoManagerNotSet:
            return "omemoManagerNotSet"
        }
    }
}

enum FileTransferError: Error {
   case failedToFormatUrl
   case failedToGetSlot
   case failedToGenerateKey
   case failedToEncryptData
   case noServer
   
   case fileTransferNotSet

   var localizedDescription: String {
       switch self {
       case .failedToFormatUrl:
           return "failedToFormatUrl"
       case .failedToGetSlot:
           return "failedToGetSlot"
       case .failedToGenerateKey:
           return "failedToGenerateKey"
       case .failedToEncryptData:
           return "failedToEncryptData"
       case .noServer:
           return "noServer"
       case .fileTransferNotSet:
           return "fileTransferNotSet"
       }
   }
}
