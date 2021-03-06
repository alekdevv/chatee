//
//  MainManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/8/21.
//

import Foundation
import XMPPFramework
import XMPPFrameworkSwift

protocol MainManagerDelegate: AnyObject {
    func mainManager(_ mainManager: MainManager, didAuthenticate authenticated: Bool)
}

private let workQueue = DispatchQueue(label: "MainManager-WorkQueue")

final class MainManager: NSObject {
    
    weak var delegate: MainManagerDelegate?
    weak var managersDelegate: (ContactManagerDelegate & PresenceManagerDelegate & VCardManagerDelegate & MessagingManagerDelegate & OmemoManagerDelegate)?
    
    var omemoManager: OmemoManager?
    var presenceManager: PresenceManager?
    var contactManager: ContactManager?
    var messagingManager: MessagingManager?
    var vCardManager: VCardManager?
    
    var isAuthenticated: Bool {
        return self.xmppStream.isAuthenticated
    }

    private let xmppStream: XMPPStream
    private let xmppReconnect: XMPPReconnect
    private let xmppPing: XMPPPing
    private var omemoModule: OMEMOModule?
    
    private var userJID: XMPPJID? {
        get {
            return Configuration.shared.userJID
        }
        set {
            Configuration.shared.userJID = newValue
        }
    }
    
    private var hostname: String? {
        return Configuration.shared.hostName
    }

    private var password: String?
    
    private var hostName: String? {
        didSet {
            Configuration.shared.hostName = self.hostName
        }
    }
    private var jidResource: String {
        return Configuration.shared.jidResource
    }

    override init() {
        self.xmppStream = XMPPStream()
        self.xmppReconnect = XMPPReconnect()
        self.xmppPing = XMPPPing()
    }
    
    deinit {
        self.xmppStream.removeDelegate(self)
        self.xmppReconnect.removeDelegate(self)
        self.xmppPing.removeDelegate(self)
    }
        
    func connect(hostName: String, bareJid: String, password: String) {
        guard self.xmppStream.isDisconnected else { return }

        self.hostName = hostName

        setupStream()
        setupReconnect()
        setupPing()
        
        self.userJID = XMPPJID(string: "\(bareJid)/\(jidResource)")
        self.xmppStream.myJID = self.userJID
        self.password = password
        
        try? self.xmppStream.connect(withTimeout: XMPPStreamTimeoutNone)
    }
    
    func disconnect() {
        self.xmppStream.disconnectAfterSending()
    }
    
    func sendChatState(_ chatState: ChateeChatState, to jid: String) {
        let xmppJid = XMPPJID(string: jid)
        let chatStateMessage = XMPPMessage(type: nil, to: xmppJid)
        
        Logger.shared.log("Sending chat state message: \(chatState.rawValue), to: \(jid)", level: .verbose)
        
        switch chatState {
        case .active:
            chatStateMessage.addActiveChatState()
        case .inactive:
            chatStateMessage.addInactiveChatState()
        case .composing:
            chatStateMessage.addComposingChatState()
        case .paused:
            chatStateMessage.addPausedChatState()
        case .gone:
            chatStateMessage.addGoneChatState()
        }
        
        self.xmppStream.send(chatStateMessage)
    }
    
    /// Used to setup stream connection with the server.
    private func setupStream() {
        self.xmppStream.hostName = hostName
        self.xmppStream.startTLSPolicy = XMPPStreamStartTLSPolicy.required
        self.xmppStream.addDelegate(self, delegateQueue: .main)
    }
    
    /// Used to connect if accidentally disconnected.
    private func setupReconnect() {
        self.xmppReconnect.activate(self.xmppStream)
    }
    
    /// Used to keep the user "active".
    private func setupPing() {
        self.xmppPing.respondsToQueries = true
        self.xmppPing.activate(self.xmppStream)
    }
    
    private func setupOmemoManager() {
        guard let userJID = self.userJID else {
            Logger.shared.log("userJID property not initialized.", level: .error)
            return
        }
        guard let hostname = self.hostname else {
            Logger.shared.log("hostname property not set.", level: .error)
            return
        }

        self.omemoManager = OmemoManager(xmppStream: xmppStream, thisUserJid: userJID, hostName: hostname)

        self.omemoModule = OMEMOModule(omemoStorage: self.omemoManager!, xmlNamespace: OMEMOModuleNamespace.conversationsLegacy)
        self.omemoModule!.addDelegate(self.omemoManager!, delegateQueue: workQueue)
        self.omemoModule!.activate(xmppStream)
        
        self.omemoManager!.initBundlePublish(omemoModule: self.omemoModule!)
        
        Logger.shared.log("Omemo Manager setup finished.", level: .verbose)
    }
    
    private func setupMessagingManager() {
        guard let userJID = self.userJID else {
            Logger.shared.log("userJID property not initialized.", level: .error)
            return
        }
        
        guard let omemoManager = self.omemoManager else {
            Logger.shared.log("omemoManager property not initialized.", level: .error)
            return
        }
        
        guard let hostname = self.hostname else {
            Logger.shared.log("hostname property not set.", level: .error)
            return
        }

        self.messagingManager = MessagingManager(xmppStream: self.xmppStream, userJID: userJID, omemoManager: omemoManager, hostName: hostname)
        self.messagingManager?.delegate = self.managersDelegate

        Logger.shared.log("Messaging Manager setup finished.", level: .verbose)
    }
    
    private func setupPresenceManager() {
        self.presenceManager = PresenceManager(xmppStream: self.xmppStream)
        self.presenceManager?.delegate = self.managersDelegate

        Logger.shared.log("Presence Manager setup finished.", level: .verbose)
    }

    private func setupVCardManager() {
        guard let userJID = self.userJID else {
            Logger.shared.log("userJID property not initialized.", level: .error)
            return
        }

        self.vCardManager = VCardManager(xmppStream: self.xmppStream, userJID: userJID)
        self.vCardManager?.delegate = self.managersDelegate
        
        Logger.shared.log("VCard Manager setup finished.", level: .verbose)
    }

    private func setupContactManager() {
        guard let userJID = self.userJID else {
            Logger.shared.log("userJID property not initialized.", level: .error)
            return
        }
        
        guard let omemoManager = self.omemoManager else {
            Logger.shared.log("omemoManager property not initialized.", level: .error)
            return
        }
        
        guard let vCardManager = self.vCardManager else {
            Logger.shared.log("vCardManager property not initialized.", level: .error)
            return
        }
        
        self.contactManager = ContactManager(xmppStream: self.xmppStream, userJID: userJID, vCardManager: vCardManager, omemoManager: omemoManager)
        self.contactManager?.delegate = self.managersDelegate
        
        Logger.shared.log("Contacts Manager setup finished.", level: .verbose)
    }

}

// MARK: - XMPPStreamDelegate
extension MainManager: XMPPStreamDelegate {
    
    func xmppStreamDidConnect(_ sender: XMPPStream) {
        Logger.shared.log("xmppStreamDidConnect", level: .verbose)

        if let password = self.password {
            try? sender.authenticate(withPassword: password)
        }
    }
    
    func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        Logger.shared.log("xmppStreamDidDisconnect withError | error \(error?.localizedDescription ?? "-")", level: .error)
    }
    
    func xmppStream(_ sender: XMPPStream, didNotAuthenticate error: DDXMLElement) {
        Logger.shared.log("xmppStream didNotAuthenticate | error \(error.localName ?? "")", level: .error)
        
//        self.errorDelegate?.serverError(error: .authenticationError)
        self.delegate?.mainManager(self, didAuthenticate: false)
    }
    
    func xmppStream(_ sender: XMPPStream, willSecureWithSettings settings: NSMutableDictionary) {
        settings[kCFStreamSSLPeerName] = hostName
        settings[GCDAsyncSocketSSLProtocolVersionMin] = NSNumber(value: SSLProtocol.tlsProtocol1.rawValue)
        settings[GCDAsyncSocketManuallyEvaluateTrust] = NSNumber(value: true)
    }
    
    func xmppStream(_ sender: XMPPStream, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
    
    func xmppStreamDidAuthenticate(_ sender: XMPPStream) {
        Logger.shared.log("xmppStreamDidAuthenticate", level: .verbose)
        
        setupOmemoManager()
        setupMessagingManager()
        setupPresenceManager()
        setupVCardManager()
        setupContactManager()

        self.delegate?.mainManager(self, didAuthenticate: true)
    }
}
