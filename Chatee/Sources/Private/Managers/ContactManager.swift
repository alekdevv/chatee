//
//  ContactsManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/9/21.
//

import Foundation
import XMPPFramework
import XMPPFrameworkSwift

protocol ContactManagerDelegate: AnyObject {
    func contactManager(_ contactManager: ContactManager, didLoadContacts contacts: [ChateeContact])
    func contactManager(_ contactManager: ContactManager, didLoadReceivedSubscriptionRequests subscriptionRequests: [ChateeContact])
    func contactManager(_ contactManager: ContactManager, didLoadSentSubscriptionRequests subscriptionRequests: [ChateeContact])

    func contactManager(_ contactManager: ContactManager, didAddContact contact: ChateeContact)
    func contactManager(_ contactManager: ContactManager, didRemoveContact contact: ChateeContact)
    func contactManager(_ contactManager: ContactManager, didReceiveSubscriptionRequest subscriptionRequest: ChateeContact)
    func contactManager(_ contactManager: ContactManager, didSendSubscriptionRequest subscriptionRequest: ChateeContact)
    
    func contactManager(_ contactManager: ContactManager, didReceivePresenceStatus presenceStatus: ChateePresenceStatus, fromContactBareJid contactBareJid: String)
    /// lastActivity represented in seconds
    func contactManager(_ contactManager: ContactManager, didReceiveContactLastActivity lastActivity: Int, fromContactBareJid contactBareJid: String)

    func contactManager(_ contactManager: ContactManager, errorOccurred error: ChateeError)
}

private let workQueue = DispatchQueue(label: "contactsManagerWorkQueue")

final class ContactManager: NSObject {
    
    weak var delegate: ContactManagerDelegate?
    
    private let xmppStream: XMPPStream
    private let xmppRosterStorage: XMPPRosterStorage
    private let xmppRoster: XMPPRoster
    private let xmppLastActivity: XMPPLastActivity
    private let userJID: XMPPJID
    
    private let vCardManager: VCardManager
    private let omemoManager: OmemoManager
    
    private let contactStorage: ContactStorage
    
    private var initialRosterLoaded = false

    init(xmppStream: XMPPStream, userJID: XMPPJID, vCardManager: VCardManager, omemoManager: OmemoManager, contactStorage: ContactStorage = ContactStorageManager()) {
        self.xmppStream = xmppStream

        self.userJID = userJID
        self.vCardManager = vCardManager
        self.omemoManager = omemoManager
        
        self.contactStorage = contactStorage

        self.xmppRosterStorage = XMPPRosterCoreDataStorage.sharedInstance()
        self.xmppRoster = XMPPRoster(rosterStorage: self.xmppRosterStorage)
        self.xmppLastActivity = XMPPLastActivity()
        
        
        super.init()
        
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
    
    // MARK: - Roster/Contacts related methods
    
    func addContact(contact: ChateeContact) {
        self.contactStorage.addContact(contact) { [weak self] savedContact, error in
            guard let self = self else {
                return
            }

            if let error = error {
                Logger.shared.log("addConntact error: \(error.localizedDescription), jid: \(contact.jid)", level: .error)

                self.delegate?.contactManager(self, errorOccurred: .database)
            } else if let savedContact = savedContact {
                Logger.shared.log("\(savedContact.jid), contact saved to the database.", level: .verbose)
                
                if savedContact.subscription == .both {
                    guard let jid = XMPPJID(string: savedContact.jid) else { return }

                    Logger.shared.log("\(savedContact.jid), should fetch devices for contact.", level: .verbose)

//                    self?.omemoManager.fetchDevices(forJid: jid)
                } else if savedContact.subscription == .requestReceived {
                    self.delegate?.contactManager(self, didReceiveSubscriptionRequest: savedContact)
                } else if savedContact.subscription == .requestSent {
                    self.delegate?.contactManager(self, didSendSubscriptionRequest: savedContact)
                }
                
//                self?.vCardManager.getVCardAvatarForContact(withJIDString: savedContact.jid, subscription: savedContact.subscription)
            }
        }
    }
    
    func removeContact(contact: ChateeContact) {
        self.contactStorage.removeContact(contact) { [weak self] removedContact, error in
            guard let self = self else {
                return
            }

            if let error = error {
                Logger.shared.log("removeContact error: \(error.localizedDescription), jid: \(contact.jid)", level: .error)

                self.delegate?.contactManager(self, errorOccurred: .database)
            } else if let removedContact = removedContact {
                Logger.shared.log("\(contact.jid), contact removed from the database.", level: .verbose)

                self.delegate?.contactManager(self, didRemoveContact: removedContact)
            }
        }
    }

    func loadContacts(subscriptionType: ChateeContactSubscription) {
        self.contactStorage.loadContacts(subscriptionType: subscriptionType) { [weak self] contacts, error in
            guard let self = self else {
                return
            }
            
            if let error = error {
                Logger.shared.log("loadContacts error: \(error.localizedDescription)", level: .error)
                
                self.delegate?.contactManager(self, errorOccurred: .database)
            } else {
                switch subscriptionType {
                case .both:
                    Logger.shared.log("Contacts `both` count: \(contacts.count)", level: .verbose)

                    self.delegate?.contactManager(self, didLoadContacts: contacts)
                case .requestReceived:
                    Logger.shared.log("Contacts `requestReceived` count: \(contacts.count)", level: .verbose)

                    self.delegate?.contactManager(self, didLoadReceivedSubscriptionRequests: contacts)
                case .requestSent:
                    Logger.shared.log("Contacts `requestSent` count: \(contacts.count)", level: .verbose)

                    self.delegate?.contactManager(self, didLoadSentSubscriptionRequests: contacts)
                default:
                    break
                }
            }
        }
    }
    
    func getAvatar(for contactJid: String) -> Data? {
        return self.contactStorage.getAvatar(contactJid: contactJid)
    }
    
    func refreshRoster() {
        self.xmppRoster.fetch()
    }
    
    func sendPresenceProbesForSubscribedContacts() {
        self.contactStorage.loadContacts(subscriptionType: .both) { [weak self] contacts, error in
            guard let self = self else {
                return
            }

            if let error = error {
                Logger.shared.log("sendPresenceProbesForSubscribedContacts error: \(error.localizedDescription)", level: .error)

                self.delegate?.contactManager(self, errorOccurred: .database)
            } else {
                self.sendPresenceProbes(contacts: contacts)
            }
        }
    }
    
    func sendPresenceProbes(contacts: [ChateeContact]) {
        contacts.forEach { sendPresenceProbe(for: $0) }
    }
    
    private func sendPresenceProbe(for contact: ChateeContact) {
        guard let jid = XMPPJID(string: contact.jid) else { return }
        guard contact.isSubscribedTo else {
            if contact.isPendingRequest {
                self.xmppRoster.subscribePresence(toUser: jid)
            }
            return
        }
        
        self.xmppStream.send(XMPPPresence(type: .probe, to: jid))
        self.xmppLastActivity.sendQuery(to: jid, withTimeout: XMPPStreamTimeoutNone)
    }
    
    // MARK: - Subscription related methods
    
    func sendSubscriptionRequest(to bareJIDString: String) {
        guard let bareJID = XMPPJID(string: bareJIDString) else { return }

        self.xmppRoster.addUser(bareJID, withNickname: nil)
    }
    
    func removeSubscription(bareJIDString: String) {
        guard let bareJID = XMPPJID(string: bareJIDString) else { return }
        
        self.xmppRoster.removeUser(bareJID)
    }
    
    func acceptSubscription(senderJID: String) {
        guard let bareJID = XMPPJID(string: senderJID) else { return }
        
        self.xmppRoster.acceptPresenceSubscriptionRequest(from: bareJID, andAddToRoster: true)
        self.xmppRoster.addUser(bareJID, withNickname: nil)
        
//        self.omemoManager.fetchDevices(forJid: bareJID)

        self.contactStorage.acceptSubscription(contactJid: senderJID) { [weak self] contact, error in
            guard let self = self else {
                return
            }

            if let error = error {
                Logger.shared.log("acceptSubscription error: \(error.localizedDescription)", level: .error)

                self.delegate?.contactManager(self, errorOccurred: .database)
            } else if let contact = contact {
                Logger.shared.log("Subscription accepted: \(contact.jid)", level: .verbose)

                self.delegate?.contactManager(self, didAddContact: contact)
            }
        }
    }

    func rejectSubscription(senderJID: String) {
        guard let bareJID = XMPPJID(string: senderJID) else { return }
        
        self.xmppRoster.rejectPresenceSubscriptionRequest(from: bareJID)
        
        self.contactStorage.rejectSubscription(contactJid: senderJID) { [weak self] success, error in
            guard let self = self else {
                return
            }

            if let error = error {
                Logger.shared.log("rejectSubscription error: \(error.localizedDescription)", level: .error)

                self.delegate?.contactManager(self, errorOccurred: .database)
            } else if success {
                // Display
                Logger.shared.log("Subscription rejected: \(senderJID)", level: .verbose)
            }
        }
    }

}

// MARK: - XMPPStreamDelegate

extension ContactManager: XMPPStreamDelegate {
    
    func xmppStream(_ sender: XMPPStream, didReceive presence: XMPPPresence) {
        guard let fromBareJID = presence.from else { return }
        
        if presence.type == "unsubscribed" {
            Logger.shared.log("xmppStream didReceive presence | from: \(fromBareJID), unsubscribed (ContactsManager)", level: .verbose)

            self.xmppRoster.removeUser(fromBareJID)
        } else if presence.type == "subscribe" {
            Logger.shared.log("xmppStream didReceive presence | from: \(fromBareJID), subscribe (ContactsManager)", level: .verbose)

            let contact = ChateeContact(jid: fromBareJID.bare, subscription: .requestReceived)

            self.addContact(contact: contact)
        } else if presence.type == "unavailable" {
            Logger.shared.log("xmppStream didReceive presence | from: \(fromBareJID), unavailable (ContactsManager)", level: .verbose)
            
            self.delegate?.contactManager(self, didReceivePresenceStatus: .offline, fromContactBareJid: fromBareJID.bare)
        } else if presence.show == "away" {
            Logger.shared.log("xmppStream didReceive presence | from: \(fromBareJID), away (ContactsManager)", level: .verbose)

            self.delegate?.contactManager(self, didReceivePresenceStatus: .away, fromContactBareJid: fromBareJID.bare)
        } else {
            Logger.shared.log("xmppStream didReceive presence | from: \(fromBareJID), presence: \(presence) (ContactsManager)", level: .verbose)

            self.delegate?.contactManager(self, didReceivePresenceStatus: .online, fromContactBareJid: fromBareJID.bare)
        }
    }
    
}

// MARK: - XMPPRosterDelegate

extension ContactManager: XMPPRosterDelegate {
    
    func xmppRoster(_ sender: XMPPRoster, didReceiveRosterItem item: DDXMLElement) {
        guard let jidString = item.attribute(forName: "jid")?.stringValue else { return }
        
        Logger.shared.log("xmppRoster didReceiveRosterItem | item jid \(jidString)", level: .verbose)
        
        if item.attribute(forName: "ask")?.stringValue != nil {
            Logger.shared.log("xmppRoster didReceiveRosterItem | \(jidString), adding contact to database as `requestSent` subscription type.", level: .verbose)

            let contact = ChateeContact(jid: jidString, subscription: .requestSent)

            addContact(contact: contact)
        } else if let subscriptionAttribute = item.attribute(forName: "subscription")?.stringValue {
            if subscriptionAttribute == "remove" {
                Logger.shared.log("xmppRoster didReceiveRosterItem | \(jidString), removing contact from the database.", level: .verbose)

                let contact = ChateeContact(jid: jidString, subscription: .none)
                
                removeContact(contact: contact)
            }
            
            if subscriptionAttribute == "both" {
                Logger.shared.log("xmppRoster didReceiveRosterItem | \(jidString), adding contact to database as `both` subscription type.", level: .verbose)

                let contact = ChateeContact(jid: jidString, subscription: .both)

                addContact(contact: contact)
            }
        }
    }
    
    func xmppRosterDidEndPopulating(_ sender: XMPPRoster) {
        Logger.shared.log("xmppRosterDidEndPopulating", level: .verbose)

        loadContacts(subscriptionType: .both)
        loadContacts(subscriptionType: .requestReceived)
        loadContacts(subscriptionType: .requestSent)
        
        initialRosterLoaded = true
    }
    
    // Show notification if you want and deal with received sub request.
    func xmppRoster(_ sender: XMPPRoster, didReceivePresenceSubscriptionRequest presence: XMPPPresence) {
        Logger.shared.log("xmppRoster didReceivePresenceSubscriptionRequest presence | From: \(String(describing: presence.from))", level: .verbose)
        
        guard let userJID = presence.from else { return }
        
        let contact = ChateeContact(jid: userJID.bare, subscription: .requestReceived)

        addContact(contact: contact)
    }
    
}

// MARK: - XMPPLastActivityDelegate

extension ContactManager: XMPPLastActivityDelegate {
    
    // Protocol method. Purpose unknown. Has to be implemented.
    func numberOfIdleTimeSeconds(for sender: XMPPLastActivity!, queryIQ iq: XMPPIQ!, currentIdleTimeSeconds idleSeconds: UInt) -> UInt {
        return 0
    }
    
    func xmppLastActivity(_ sender: XMPPLastActivity!, didNotReceiveResponse queryID: String!, dueToTimeout timeout: TimeInterval) {
        Logger.shared.log("xmppLastActivity didNotReceiveResponse queryID | \(queryID ?? "")", level: .verbose)
    }
    
    func xmppLastActivity(_ sender: XMPPLastActivity!, didReceiveResponse response: XMPPIQ!) {
        guard let fromJID = response.from else { return }
        
        let seconds = response.lastActivitySeconds()

        // When user is removed from the roster, server sometimes respond with a bad last activity.
        // 9223372036854775807 seconds is too big for last activity, so user is removed.
        guard seconds < 9223372036854775807 else {
            Logger.shared.log("xmppLastActivity didReceiveResponse response | Should be removed: \(fromJID)", level: .verbose)

            self.xmppRoster.removeUser(fromJID)
            
            let contact = ChateeContact(jid: fromJID.bare, subscription: .none)
            
            removeContact(contact: contact)
            
            return
        }
        
        Logger.shared.log("xmppLastActivity didReceiveResponse response | Last activity from: \(fromJID), seconds ago: \(seconds)", level: .verbose)
        
        self.delegate?.contactManager(self, didReceiveContactLastActivity: Int(seconds), fromContactBareJid: fromJID.bare)
    }
}

