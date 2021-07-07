//
//  ChateeRecentConversation.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public struct ChateeRecentConversation {
    public var contact: ChateeContact
    public var lastMessage: ChateeMessage
    public var presenceStatus: ChateePresenceStatus = .offline
}
