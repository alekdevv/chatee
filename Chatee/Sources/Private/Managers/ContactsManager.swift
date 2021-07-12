//
//  ContactsManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import XMPPFramework
import XMPPFrameworkSwift

protocol ContactsManagerDelegate: AnyObject {
    
}

private let workQueue = DispatchQueue(label: "contactsManagerWorkQueue")

class ContactsManager {
    
    weak var delegate: ContactsManagerDelegate?
    
    private let xmppStream: XMPPStream
    private let xmppRosterStorage: XMPPRosterStorage
    private let xmppRoster: XMPPRoster
    private let xmppLastActivity: XMPPLastActivity
    private let userJID: XMPPJID
    
    private let vCardManager: VCardManager
    private let omemoManager: OmemoManager
    
    private let contactStorage: ContactStorage

    init(xmppStream: XMPPStream, userJID: XMPPJID, vCardManager: VCardManager, omemoManager: OmemoManager) {
        self.xmppStream = xmppStream

        self.userJID = userJID
        self.vCardManager = vCardManager
        self.omemoManager = omemoManager
        
        self.xmppRosterStorage = XMPPRosterCoreDataStorage.sharedInstance()
        self.xmppRoster = XMPPRoster(rosterStorage: self.xmppRosterStorage)
        self.xmppLastActivity = XMPPLastActivity()
        
        self.contactStorage = ContactStorageManager()
        
        self.xmppStream.addDelegate(self, delegateQueue: workQueue)

        setupRoster()
        setupLastActivity()
    }
    
    deinit {
        self.xmppStream.removeDelegate(self)
    }
    
    private func setupRoster() {
        self.xmppRoster.addDelegate(self, delegateQueue: workQueue)
        self.xmppRoster.autoFetchRoster = false
        self.xmppRoster.autoClearAllUsersAndResources = false
        self.xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = true
        self.xmppRoster.activate(xmppStream)
    }
    
    /// Publish last activity of this user
    private func setupLastActivity() {
        self.xmppLastActivity.addDelegate(self, delegateQueue: workQueue)
        self.xmppLastActivity.activate(self.xmppStream)
    }

}
