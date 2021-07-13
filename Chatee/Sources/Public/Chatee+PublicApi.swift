//
//  Chatee+PublicApi.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/13/21.
//

import Foundation

extension Chatee {
    
    private var contactManager: ContactManager? {
        return xmppManager.contactManager
    }

    private var presenceManager: PresenceManager? {
        return xmppManager.presenceManager
    }

    private var vCardManager: VCardManager? {
        return xmppManager.vCardManager
    }
    
    private var messagingManager: MessagingManager? {
        return xmppManager.messagingManager
    }
    
    /// Used to connect to the server.
    /// - Parameters:
    ///     - hostName: Host server url.
    ///     - bareJid: Bare jid of a user to connect with.
    ///     - password: If there is authentication for this user, provide password. It's optional.
    public func connect(hostName: String, bareJid: String, password: String?) {
        self.xmppManager.connect(hostName: hostName, bareJid: bareJid, password: password ?? "")
    }
    
    /// Used to disconnect from the server
    public func disconnect() {
        guard self.xmppManager.isAuthenticated else {
            return
        }
        
        self.xmppManager.disconnect()
    }
    
    /// Used to send presence to the server.
    /// - Parameters:
    ///     - presenceStatus: Current presence status.
    public func sendPresenceStatus(_ presenceStatus: ChateePresenceStatus) {
        guard self.xmppManager.isAuthenticated else {
            return
        }
        
        guard let presenceManager = self.presenceManager else {
            return
        }
        
        presenceManager.sendPresenceStatus(presenceStatus)
    }

}
