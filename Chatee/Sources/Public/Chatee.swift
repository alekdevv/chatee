//
//  Chatee.swift
//  Chatee
//
//  Created by Nikola Aleksendric on 7/7/21.
//

import Foundation

public final class Chatee {
    
    public static let shared = Chatee()
    
    public weak var chateeProfileDelegate: ChateeProfileDelegate?
    public weak var chateeConversationDelegate: ChateeProfileDelegate?
    public weak var chateeContactsDelegate: ChateeProfileDelegate?
    public weak var chateeErrorDelegate: ChateeProfileDelegate?
    
    public var encryptionType: EncryptionType? {
        didSet {
            guard let encryptionType = self.encryptionType else {
                return
            }
            
            Configuration.shared.encryptionType = encryptionType
        }
    }
    
    let xmppManager: XMPPManager
    
    private init() {
        self.xmppManager = XMPPManager()
        self.xmppManager.managersDelegate = self
    }
    
}
