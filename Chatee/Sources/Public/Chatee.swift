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
    public weak var chateeConversationDelegate: ChateeConversationDelegate?
    public weak var chateeContactDelegate: ChateeContactDelegate?
    public weak var chateeErrorDelegate: ChateeErrorDelegate?
    
    public var encryptionType: EncryptionType? {
        didSet {
            guard let encryptionType = self.encryptionType else {
                return
            }
            
            Configuration.shared.encryptionType = encryptionType
        }
    }
    
    let mainManager: MainManager
    
    private init() {
        self.mainManager = MainManager()
        self.mainManager.delegate = self
        self.mainManager.managersDelegate = self
    }
    
}
