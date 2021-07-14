//
//  Chatee+PublicApi.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/13/21.
//

import Foundation

extension Chatee {
    
    private var contactManager: ContactManager? {
        return self.mainManager.contactManager
    }

    private var presenceManager: PresenceManager? {
        return self.mainManager.presenceManager
    }

    private var vCardManager: VCardManager? {
        return self.mainManager.vCardManager
    }
    
    private var messagingManager: MessagingManager? {
        return self.mainManager.messagingManager
    }
    
    /// Connects the user to the server.
    /// - Parameters:
    ///     - hostName: Server host url.
    ///     - bareJid: Bare jid of the user to connect with.
    ///     - password: If there is authentication for this user, provide a password. Optional.
    public func connect(hostName: String, bareJid: String, password: String?) {
        self.mainManager.connect(hostName: hostName, bareJid: bareJid, password: password ?? "")
    }
    
    /// Disconnects the user from the server.
    public func disconnect() {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        self.mainManager.disconnect()
    }
    
    /// Sends user presence status to the server.
    /// - Parameters:
    ///     - presenceStatus: Current presence status of the user.
    public func sendPresenceStatus(_ presenceStatus: ChateePresenceStatus) {
        guard self.mainManager.isAuthenticated else {
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
    ///     - bareJid: Bare jid of the user who sent the subscription request.
    public func acceptSubscription(from bareJid: String) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let contactManager = self.contactManager else {
            return
        }

        contactManager.acceptSubscription(senderJid: bareJid)
    }
    
    /// Rejects subscription request from the user with the given bareJid
    /// - Parameters:
    ///     - bareJid: Bare jid of the user who sent the subscription request.
    public func rejectSubscription(from bareJid: String) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let contactManager = self.contactManager else {
            return
        }

        contactManager.rejectSubscription(senderJid: bareJid)
    }
    
    /// Sends a subscription request to the user with the given bare jid.
    /// - Parameters:
    ///     - bareJid: A bare jid of the user to whom the subscription request is sent.
    public func sendSubscriptionRequest(to bareJid: String) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let contactManager = self.contactManager else {
            return
        }

        contactManager.sendSubscriptionRequest(to: bareJid)
    }

    /// Removes a subscription to the user with the given bare jid.
    /// - Parameters:
    ///     - bareJid: A bare jid of the subscribed user.
    public func removeSubscription(with bareJid: String) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let contactManager = self.contactManager else {
            return
        }

        contactManager.removeSubscription(bareJIDString: bareJid)
    }
    
    /// Loads contacts from the roster with the given subscription type.
    /// - Parameters:
    ///     - subscryptionType:
    public func loadContacts(with subscriptionType: ChateeContactSubscription) {
        guard self.mainManager.isAuthenticated else {
            return
        }

        guard let contactManager = self.contactManager else {
            return
        }

        contactManager.loadContacts(subscriptionType: subscriptionType)
    }
    
    /// Sends presence probes for subscribed contacts.
    public func sendPresenceProbesForSubscribedContacts() {
        guard self.mainManager.isAuthenticated else {
            return
        }

        guard let contactManager = self.contactManager else {
            return
        }

        contactManager.sendPresenceProbesForSubscribedContacts()
    }

    /// Sends presence probes for specific contacts.
    /// - Parameters:
    ///     - contacts: List of contacts.
    public func sendPresenceProbes(for contacts: [ChateeContact]) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let contactManager = self.contactManager else {
            return
        }

        contactManager.sendPresenceProbes(contacts: contacts)
    }
    
    /// Returns the user's avatar.
    /// - Parameters:
    ///     - contactJid: User's bare jid.
    public func getAvatar(for contactBareJid: String) -> Data? {
        guard self.mainManager.isAuthenticated else {
            return nil
        }

        guard let contactManager = self.contactManager else {
            return nil
        }

        return contactManager.getAvatar(for: contactBareJid)
    }
    
    /// Loads a conversation with the user.
    /// - Parameters:
    ///     - bareJid: Bare jid of the user.
    public func loadConversation(with bareJid: String) {
        guard self.mainManager.isAuthenticated else {
            self.chateeErrorDelegate?.chateeError(self, type: .xmpp(error: .notAuthenticated))
            return
        }
        
        guard let messagingManager = self.messagingManager else {
            return
        }

        messagingManager.loadConversation(withID: bareJid)
    }
    
    /// Loads conversations list.
    public func loadRecentConversations() {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let messagingManager = self.messagingManager else {
            return
        }

        messagingManager.loadRecentConversations()
    }
    
    /// Loads all archived messages from the server.
    public func loadServerArhivedMessagesForContacts(contactJids: [String]) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let messagingManager = self.messagingManager else {
            return
        }
        
        messagingManager.loadServerArhivedMessagesFor(contactJids: contactJids)
    }

    /// Returns number of unread messages.
    public func getUnreadMessagesCount() -> Int {
        guard self.mainManager.isAuthenticated else {
            return 0
        }
        
        // TODO: Unread messages count
        return 0
    }
    
    /// Returns number of unread messages for specific contact.
    /// - Parameters:
    ///     - contactJid: Bare jid of the contact.
    public func unreadMessagesCount(for contactJid: String) -> Int {
        guard self.mainManager.isAuthenticated else {
            return 0
        }
        
        // TODO: Unread messages count for contact
        return 0
    }

    /// Sends a text message to the contact.
    /// - Parameters:
    ///     - text: Text input of the message.
    ///     - toJid: Recepient's bare jid.
    public func sendMessage(text: String, to contactJid: String) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let messagingManager = self.messagingManager else {
            return
        }
        
        messagingManager.sendMessage(messageID: UUID().uuidString, text: text, to: contactJid)
    }
    
    /// Sends a file to the contact.
    /// - Parameters:
    ///     - data: File data.
    ///     - toJid: Recepient's bare jid.
    public func sendFile(_ data: Data, to contactJid: String) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let messagingManager = self.messagingManager else {
            return
        }

        messagingManager.sendFile(messageID: UUID().uuidString, data: data, to: contactJid)
    }
    
    /// Forces service to send outgoing messages immediately.
    public func forceSendOutgoingMessages() {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let messagingManager = self.messagingManager else {
            return
        }

        messagingManager.forceSendOutgoingMessages()
    }
    
    /// Sends chat state to contact.
    /// - Parameters:
    ///     - chatState: Current chat state.
    ///     - contactJid: Bare Jid of the contact.
    public func sendChatState(_ chatState: ChateeChatState, to contactJid: String) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        
        self.mainManager.sendChatState(chatState, to: contactJid)
    }
        
    /// Changes avatar of this user.
    /// - Parameters:
    ///     - imageData: Data of the avatar image to bi uploaded to the server.
    public func changeAvatar(with imageData: Data) {
        guard self.mainManager.isAuthenticated else {
            return
        }
        
        guard let vCardManager = self.vCardManager else {
            return
        }

        vCardManager.changeAvatar(with: imageData)
    }

}
