//
//  Chatee+Delegates.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

// MARK: - MainManagerDelegate
extension Chatee: MainManagerDelegate {
    
    func mainManager(_ mainManager: MainManager, didAuthenticate authenticated: Bool) {
        self.chateeProfileDelegate?.chateeProfile(self, didAuthenticate: authenticated)
    }
    
}

// MARK: - ContactManagerDelegate

extension Chatee: ContactManagerDelegate {
    
    func contactManager(_ contactManager: ContactManager, didLoadContacts contacts: [ChateeContact]) {
        
    }
    
    func contactManager(_ contactManager: ContactManager, didLoadReceivedSubscriptionRequests subscriptionRequests: [ChateeContact]) {
        
    }
    
    func contactManager(_ contactManager: ContactManager, didLoadSentSubscriptionRequests subscriptionRequests: [ChateeContact]) {
        
    }
    
    func contactManager(_ contactManager: ContactManager, didAddContact contact: ChateeContact) {
        
    }
    
    func contactManager(_ contactManager: ContactManager, didRemoveContact contact: ChateeContact) {
        
    }
    
    func contactManager(_ contactManager: ContactManager, didReceiveSubscriptionRequest subscriptionRequest: ChateeContact) {
        
    }
    
    func contactManager(_ contactManager: ContactManager, didSendSubscriptionRequest subscriptionRequest: ChateeContact) {
        
    }
    
    func contactManager(_ contactManager: ContactManager, didReceivePresenceStatus presenceStatus: ChateePresenceStatus, fromContactBareJid contactBareJid: String) {
        
    }
    
    func contactManager(_ contactManager: ContactManager, didReceiveContactLastActivity lastActivity: Int, fromContactBareJid contactBareJid: String) {
        
    }
    
    func contactManager(_ contactManager: ContactManager, errorOccurred error: ChateeError) {
        
    }
    
}

// MARK: - VCardManagerDelegate

extension Chatee: VCardManagerDelegate {
    
    func vCardManager(_ vCardManager: VCardManager, userDidChangeAvatar avatar: Data) {
        self.chateeProfileDelegate?.chateeProfile(self, didChangeAvatar: avatar)
    }
    
    func vCardManager(_ vCardManager: VCardManager, didLoadContactAvatar avatar: Data, forContactJid contactJid: String) {
        
    }
    
    func vCardManager(_ vCardManager: VCardManager, errorOccurred error: ChateeError) {
        
    }
    
}

// MARK: - PresenceManagerDelegate

extension Chatee: PresenceManagerDelegate {
    
    func presenceManager(_ presenceManager: PresenceManager, didReceiveContactPresenceStatus presenceStatus: ChateePresenceStatus, forContactBareJid contactBareJid: String) {
        
    }

}

// MARK: - MessagingManagerDelegate

extension Chatee: MessagingManagerDelegate {
    
    func messagingManager(_ messagingManager: MessagingManager, didLoadRecentConversations recentConversations: [ChateeRecentConversation]) {
        
    }
    
    func messagingManager(_ messagingManager: MessagingManager, didLoadConversation conversation: ChateeConversation) {
        
    }
    
    func messagingManager(_ messagingManager: MessagingManager, didAddNewMessage message: ChateeMessage, forRoomID roomID: String) {
        
    }
    
    func messagingManager(_ messagingManager: MessagingManager, didMarkMessageAs messageStatus: ChateeMessageStatus, forMessageID messageID: String) {
        
    }
    
    func messagingManager(_ messagingManager: MessagingManager, errorOccurred error: ChateeError) {
        
    }
    
}

// MARK: - OmemoManagerDelegate

extension Chatee: OmemoManagerDelegate {
    
    func omemoManager(_ omemoManager: OmemoManager, didAddNewMessage message: ChateeMessage, forRoomID roomID: String) {
        
    }
    
    func omemoManager(_ omemoManager: OmemoManager, didMarkMessageAs messageStatus: ChateeMessageStatus, forMessageID messageID: String) {
        
    }
    
    func omemoManager(_ omemoManager: OmemoManager, errorOccurred error: ChateeError) {
        
    }

}
