//
//  PresenceManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/13/21.
//

import Foundation
import XMPPFramework
import XMPPFrameworkSwift

protocol PresenceManagerDelegate: AnyObject {
    func presenceManager(_ presenceManager: PresenceManager, didReceiveContactPresenceStatus presenceStatus: ChateePresenceStatus, forContactBareJid contactBareJid: String)
}

private let workQueue = DispatchQueue(label: "PresenceManager-WorkQueue")

final class PresenceManager {
    
    weak var delegate: PresenceManagerDelegate?
    
    private let xmppStream: XMPPStream
    

    init(xmppStream: XMPPStream) {
        self.xmppStream = xmppStream

        self.xmppStream.addDelegate(self, delegateQueue: workQueue)
    }
    
    deinit {
        self.xmppStream.removeDelegate(self)
    }
    
    func sendPresenceStatus(_ presenceStatus: ChateePresenceStatus) {
        switch presenceStatus {
        case .online:
            goOnline()
        case .away:
            goAway()
        case .offline:
            goOffline()
        }
    }
    
    private func goOnline() {
        Logger.shared.log("goOnline called", level: .verbose)
        
        if self.xmppStream.isConnected {
            let availablePresence = XMPPPresence()
            
            self.xmppStream.send(availablePresence)
        }
    }
    
    private func goAway() {
        Logger.shared.log("goAway called", level: .verbose)
        
        let awayPresence = XMPPPresence()
        let showElement = XMLElement(name: "show", stringValue: "away")
        awayPresence.addChild(showElement)

        self.xmppStream.send(awayPresence)
    }
    
    private func goOffline() {
        Logger.shared.log("goOffline called", level: .verbose)

        let offlinePresence = XMPPPresence(type: .unavailable)
        offlinePresence.addIdle(since: Date())
        
        self.xmppStream.send(offlinePresence)
    }
}

// MARK: - XMPPStreamDelegate

extension PresenceManager: XMPPStreamDelegate {
    func xmppStream(_ sender: XMPPStream, didSend presence: XMPPPresence) {
        Logger.shared.log("xmppStream didSend | presence \(presence)", level: .verbose)
    }
    
    func xmppStream(_ sender: XMPPStream, didReceive presence: XMPPPresence) {
        guard let fromBareJID = presence.from else { return }
        
        Logger.shared.log("xmppStream didReceive | presence \(presence) (PresenceManager)", level: .verbose)
        
        if presence.type == "unavailable" {
            self.delegate?.presenceManager(self, didReceiveContactPresenceStatus: .offline, forContactBareJid: fromBareJID.bare)
        } else if presence.show == "away" {
            self.delegate?.presenceManager(self, didReceiveContactPresenceStatus: .away, forContactBareJid: fromBareJID.bare)
        } else {
            self.delegate?.presenceManager(self, didReceiveContactPresenceStatus: .online, forContactBareJid: fromBareJID.bare)
        }
    }
}
