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
    
    /// Connects the user to the server.
    /// - Parameters:
    ///     - hostName: Server host url.
    ///     - bareJid: Bare jid of the user to connect with.
    ///     - password: If there is authentication for this user, provide a password. Optional.
    public func connect(hostName: String, bareJid: String, password: String?) {
        self.xmppManager.connect(hostName: hostName, bareJid: bareJid, password: password ?? "")
    }
    
    /// Disconnects the user from the server.
    public func disconnect() {
        guard self.xmppManager.isAuthenticated else {
            return
        }
        
        self.xmppManager.disconnect()
    }
    
    /// Sends user presence status to the server.
    /// - Parameters:
    ///     - presenceStatus: Current presence status of the user.
    public func sendPresenceStatus(_ presenceStatus: ChateePresenceStatus) {
        guard self.xmppManager.isAuthenticated else {
            return
        }
        
        guard let presenceManager = self.presenceManager else {
            return
        }
        
        presenceManager.sendPresenceStatus(presenceStatus)
    }

    /// Accepts subscription request from the user with the given bareJid
    /// - By accepting the subscription request, the user adds another user to the list and can communicate with him.
    /// - Parameters:
    ///     - bareJid: Bare Jid of the user who sent the subscription request.
    public func acceptSubscription(fromBareJid bareJid: String) {
        guard self.xmppManager.isAuthenticated else {
            return
        }
        
        guard let contactManager = self.contactManager else {
            return
        }

        contactManager.acceptSubscription(senderJid: bareJid)
    }
    
    /// Rejects subscription request from the user with the given bareJid
    /// - Parameters:
    ///     - bareJid: Bare Jid of the user who sent the subscription request.
    public func rejectSubscription(fromBareJid bareJid: String) {
        guard self.xmppManager.isAuthenticated else {
            return
        }
        
        guard let contactManager = self.contactManager else {
            return
        }

        contactManager.rejectSubscription(senderJid: bareJid)
    }

}
