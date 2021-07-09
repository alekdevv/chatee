//
//  ChateeMessage.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public struct ChateeMessage {
    public let id: String
    public let senderID: String
    public let senderName: String?
    public let text: String
    public let extraBody: Data?
    public let timestamp: Date
    public let status: ChateeMessageStatus
    
    static func convert(dbMessage: MessageDBModel) -> ChateeMessage {
        return ChateeMessage(id: dbMessage.id, senderID: dbMessage.senderID, senderName: dbMessage.room?.displayName, text: dbMessage.text,
                            extraBody: nil, timestamp: dbMessage.timestamp, status: dbMessage.statusType)
    }

    static func convert(dbMessages: [MessageDBModel]) -> [ChateeMessage] {
        let messages = dbMessages.map { return convert(dbMessage: $0) }

        return messages
    }
}
