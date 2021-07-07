//
//  ChateeContact.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public struct ChateeContact {
    public var jid: String
    public var name: String?
    public var status: String?
    public var lastActive: String?
    public var avatar: Data?
        
    public var presenceStatus: ChateePresenceStatus = .offline
    public var subscription: ChateeContactSubscription

    var isSubscribedTo: Bool {
        return self.subscription == .both || self.subscription == .to
    }
    
    var isPendingRequest: Bool {
        return self.subscription == .requestSent
    }
}
