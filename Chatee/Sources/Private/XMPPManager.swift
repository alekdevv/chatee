//
//  XMPPManager.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/8/21.
//

import Foundation
import XMPPFramework
import XMPPFrameworkSwift

protocol XMPPManagerDelegate: AnyObject {
    func xmppManager(_ xmppManager: XMPPManager, loggedIn: Bool)
}

class XMPPManager {
    
    weak var delegate: XMPPManagerDelegate?
    
    private let xmppStream: XMPPStream
    private let xmppReconnect: XMPPReconnect
    private let xmppPing: XMPPPing
    private var omemoModule: OMEMOModule?
    
    private var userJID: XMPPJID? {
        didSet {
            Configuration.shared.userJID = self.userJID
        }
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

    init() {
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
    
    private func setupContactsManager() {
        
    }

}

// MARK: - XMPPStreamDelegate
extension XMPPManager: XMPPStreamDelegate {
    
    func xmppStreamDidConnect(_ sender: XMPPStream) {
        Logger.shared.log("xmppStreamDidConnect", level: .verbose)

        if let password = self.password {
            try! sender.authenticate(withPassword: password)
        }
    }
    
    func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        Logger.shared.log("xmppStreamDidDisconnect withError | error \(error?.localizedDescription ?? "-")", level: .error)
    }
    
    func xmppStream(_ sender: XMPPStream, didNotAuthenticate error: DDXMLElement) {
        Logger.shared.log("xmppStream didNotAuthenticate | error \(error.localName ?? "")", level: .error)
        
//        self.errorDelegate?.serverError(error: .authenticationError)
        self.delegate?.xmppManager(self, loggedIn: false)
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
        
//        setupOmemoManager()
//        setupMessagingManager()
//        setupPresenceManager()
//        setupVCardManager()
        setupContactsManager()

        self.delegate?.xmppManager(self, loggedIn: true)
    }
}
