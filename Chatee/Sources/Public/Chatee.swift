//
//  Chatee.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public class Chatee {
    
    public static let shared = Chatee()
    
    public weak var chateeProfileDelegate: ChateeProfileDelegate?
    public weak var chateeConversationDelegate: ChateeProfileDelegate?
    public weak var chateeContactsDelegate: ChateeProfileDelegate?
    public weak var chateeErrorDelegate: ChateeProfileDelegate?
    
    private let xmppManager: XMPPManager
    
    private init() {
        self.xmppManager = XMPPManager()
    }
    
    /// Used to connect with XMPP server.
    public func connect(hostName: String, bareJid: String, password: String) {
        self.xmppManager.connect(hostName: hostName, bareJid: bareJid, password: password)
    }
    
}
